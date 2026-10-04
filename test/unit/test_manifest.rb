# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Manifest do
  let(:obs_link) { ::PackmanNova::Manifest.load_file(fixture_path('packages', 'ffmpeg-8', 'package.yml')) }
  let(:native) { ::PackmanNova::Manifest.load_file(fixture_path('packages', 'gstreamer-plugins-bad-codecs', 'package.yml')) }

  def write_manifest(dir, name, yaml, files: {})
    package_dir = ::File.join(dir, name)
    ::FileUtils.mkdir_p(package_dir)
    ::File.write(::File.join(package_dir, 'package.yml'), yaml)
    files.each { |file, content| ::File.write(::File.join(package_dir, file), content) }
    ::File.join(package_dir, 'package.yml')
  end

  def manifest_error(yaml, name: 'pkg', files: { 'pkg.spec' => '' })
    with_tmpdir do |dir|
      path = write_manifest(dir, name, yaml, files: files)
      assert_raises(::PackmanNova::ManifestError) { ::PackmanNova::Manifest.load_file(path) }
    end
  end

  describe 'obs-link' do
    it 'exposes identity and metadata' do
      assert_equal ['ffmpeg-8', 'obs-link', 2], [obs_link.name, obs_link.kind, obs_link.tier]
      assert_predicate obs_link, :obs_link?
      assert_predicate obs_link, :enabled?
    end

    it 'defaults the origin package to the name' do
      assert_equal ::PackmanNova::Manifest::Origin.new(project: 'openSUSE:Factory', package: 'ffmpeg-8', pin: nil), obs_link.origin
      assert_equal 'openSUSE:Factory/ffmpeg-8', obs_link.origin.to_s
    end

    it 'parses link rules' do
      assert_equal %w[_multibuild ffmpeg-8.changes], obs_link.link_rules.delete
      assert obs_link.link_rules.deletes?('_multibuild')
    end

    it 'defaults the origin project and spec name' do
      with_tmpdir do |dir|
        manifest = ::PackmanNova::Manifest.load_file(write_manifest(dir, 'vlc', "name: vlc\nkind: obs-link\n"))

        assert_equal 'openSUSE:Factory', manifest.origin.project
        assert_equal 'vlc.spec', manifest.spec_name
        assert_empty manifest.sources
      end
    end
  end

  describe 'native' do
    it 'exposes kind, tags and enabled flag' do
      assert_predicate native, :native?
      refute_predicate native, :enabled?
      assert_equal %w[codec proprietary], native.tags
    end

    it 'parses url sources with lowercase sha256 and size' do
      source = native.sources.first

      assert_equal '_service:download_files:gst-plugins-bad-1.28.7.tar.xz', source.file
      assert_equal 8_347_976, source.size
      assert_equal '9c4a5b0e7a1f3c2d4b6e8f0a1c3e5b7d9f1a3c5e7b9d1f3a5c7e9b1d3f5a7c9e', source.sha256
    end

    it 'classifies url schemes' do
      source = native.sources.first

      assert_equal(%i[http pmbs pmbs mirror_src], source.urls.map { |url| source.scheme(url) })
    end

    it 'parses pmbs and mirror-src urls' do
      source = native.sources.first

      assert_equal ['gstreamer-plugins-bad-codecs', source.file], [source.pmbs_package(source.urls[1]), source.pmbs_file(source.urls[1])]
      assert_equal 'gst-plugins-bad-1.28.7.tar.xz', source.pmbs_file(source.urls[2])
      assert_equal 'gstreamer-plugins-bad-codecs', source.mirror_package(source.urls[3])
    end

    it 'parses local path sources' do
      source = native.sources[1]

      assert_predicate source, :local?
      refute_predicate source, :remote?
      assert_equal 'docs/README.SUSE', source.path
    end

    it 'parses generated sources' do
      source = native.sources.last

      assert_predicate source, :generated?
      refute_predicate source, :remote?
      assert_equal 'public-key', source.generated
    end

    it 'lists vendored files without manifest, provenance and source files' do
      assert_equal(%w[build_what_we_need_only.patch gstreamer-plugins-bad-codecs.spec], native.vendored_files.map { |path| ::File.basename(path) })
      assert_equal native.dir, ::File.dirname(native.vendored_files.first)
    end

    it 'accepts missing sha256 when checksums are not required' do
      with_tmpdir do |dir|
        path = write_manifest(dir, 'pkg', "name: pkg\nkind: native\nsources:\n  - file: a.tar.gz\n    urls: [https://example.org/a.tar.gz]\n", files: { 'pkg.spec' => '' })

        assert_nil ::PackmanNova::Manifest.load_file(path, require_checksums: false).sources.first.sha256
      end
    end
  end

  describe 'validation' do
    it 'requires the spec file for native packages' do
      error = manifest_error("name: pkg\nkind: native\n", files: {})

      assert_match(/package pkg: spec: pkg\.spec not found/, error.message)
    end

    it 'accepts a spec override' do
      with_tmpdir do |dir|
        path = write_manifest(dir, 'pkg', "name: pkg\nkind: native\nspec: other.spec\n", files: { 'other.spec' => '' })

        assert_equal 'other.spec', ::PackmanNova::Manifest.load_file(path).spec_name
      end
    end

    it 'rejects unknown kinds' do
      assert_match(/package pkg: kind: must be one of obs-link, native/, manifest_error("name: pkg\nkind: git\n").message)
    end

    it 'requires sha256 for url sources' do
      error = manifest_error("name: pkg\nkind: native\nsources:\n  - file: a.tar.gz\n    urls: [https://example.org/a.tar.gz]\n")

      assert_match(/package pkg: sources\[0\]\.sha256: missing/, error.message)
    end

    it 'rejects unknown generated sources and mixed source kinds' do
      assert_match(/sources\[0\]\.generated: must be one of public-key/, manifest_error("name: pkg\nkind: native\nsources:\n  - file: a\n    generated: x\n").message)
      error = manifest_error("name: pkg\nkind: native\nsources:\n  - file: a\n    path: a\n    generated: public-key\n")

      assert_match(/sources\[0\]: needs exactly one of urls, path or generated/, error.message)
    end

    it 'rejects unsupported url schemes' do
      error = manifest_error("name: pkg\nkind: native\nsources:\n  - file: a\n    urls: [ftp://x/a]\n    sha256: #{'a' * 64}\n")

      assert_match(/sources\[0\]\.urls: unsupported url/, error.message)
    end

    it 'rejects a name that does not match the directory' do
      assert_match(/name: "other" does not match directory "pkg"/, manifest_error("name: other\nkind: obs-link\n").message)
    end

    it 'rejects keys of the other kind' do
      assert_match(/unknown key\(s\) sources/, manifest_error("name: pkg\nkind: obs-link\nsources: []\n").message)
    end

    it 'requires exactly one of urls, path or generated' do
      error = manifest_error("name: pkg\nkind: native\nsources:\n  - file: a\n")

      assert_match(/sources\[0\]: needs exactly one of urls, path or generated/, error.message)
    end

    it 'rejects non-boolean enabled' do
      assert_match(/enabled: must be true or false/, manifest_error("name: pkg\nkind: obs-link\nenabled: yes please\n").message)
    end
  end
end

describe ::PackmanNova::Manifest::Loader do
  let(:loader) { ::PackmanNova::Manifest::Loader.new(packages_dir: fixture_path('packages')) }

  it 'loads all manifests sorted by name' do
    assert_equal %w[ffmpeg-8 gstreamer-plugins-bad-codecs], loader.all.map(&:name)
  end

  it 'filters enabled manifests' do
    assert_equal %w[ffmpeg-8], loader.enabled.map(&:name)
  end

  it 'skips directories without package.yml and ignores _ and . dirs' do
    assert_equal %w[unmanaged], loader.skipped
  end

  it 'finds by name or raises' do
    assert_equal 'ffmpeg-8', loader.find('ffmpeg-8').name
    assert_raises(::PackmanNova::ManifestError) { loader.find('nope') }
  end

  it 'collects errors and raises the first from all' do
    with_tmpdir do |dir|
      ::FileUtils.mkdir_p(::File.join(dir, 'broken'))
      ::File.write(::File.join(dir, 'broken', 'package.yml'), "name: broken\nkind: nope\n")
      broken = ::PackmanNova::Manifest::Loader.new(packages_dir: dir)

      assert_equal 1, broken.errors.size
      assert_raises(::PackmanNova::ManifestError) { broken.all }
    end
  end
end
