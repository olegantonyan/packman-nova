# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Site::Generator, :site do
  let(:state) { site_state }
  let(:generator) { ::PackmanNova::Site::Generator.new(config: site_config, states: { 'opensuse_tumbleweed' => state }, logger: null_logger) }

  def render(page_state)
    ::PackmanNova::Site::Generator.new(config: site_config, states: { 'opensuse_tumbleweed' => page_state }, logger: null_logger).render('index.html')
  end
  let(:html) { generator.render('index.html') }

  it 'renders the install commands' do
    assert_includes html, 'sudo zypper ar -f -p 80 https://packman.example.org/opensuse_tumbleweed/essentials/packman-nova.repo'
    assert_includes html, 'sudo zypper --gpg-auto-import-keys ref'
    assert_includes html, 'sudo zypper dup --from packman-nova-essentials --allow-vendor-change'
  end

  it 'renders the key and repository facts' do
    assert_includes html, '0A1B 2C3D 4E5F 6071 8293 A4B5 C6D7 E8F9 3F1C 2A9B'
    assert_includes html, 'C6D7 E8F9 3F1C 2A9B'
    assert_includes html, 'https://packman.example.org/packman-nova.key'
    assert_includes html, '20260927'
    assert_includes html, '<title>packman-nova: Packman codecs for openSUSE Tumbleweed and Leap 16</title>'
    assert_includes html, '<li><a href="https://github.com/olegantonyan/packman-nova">Source code</a></li>'
    assert_includes html, 'data-api="https://api.github.com/repos/olegantonyan/packman-nova/actions/workflows/build-publish.yml/runs?per_page=1"'
    assert_includes html, '<li><a href="https://omnipackage.org">omnipackage.org</a></li>'
    assert_includes html, '<li><a href="https://github.com/olegantonyan/packman-nova/issues">Report an issue</a></li>'
    assert_includes html, '<li><a href="https://packman.example.org/opensuse_tumbleweed/essentials/packman-nova.repo">openSUSE Tumbleweed</a></li>'
    assert_includes html, '<li>openSUSE Leap 16.0 <span class="footer-soon">soon</span></li>'
  end

  it 'renders every package with its version' do
    state.fetch('packages').each do |name, entry|
      assert_includes html, ">#{name}</a>"
      assert_includes html, "#{entry.fetch('version')}-#{entry.fetch('release')}"
    end
    assert_includes html, 'https://build.opensuse.org/package/show/openSUSE:Factory/vlc'
  end

  it 'escapes state values' do
    assert_includes html, 'meta change: ffmpeg-8-libavcodec-devel &lt;8.1.3&gt;'
    refute_includes html, '<8.1.3>'
  end

  it 'collapses the rebuild details of a succeeded package and keeps a failure reason visible' do
    collapsed = state.merge('packages' => state.fetch('packages').merge('ffmpeg-8' => state.dig('packages', 'ffmpeg-8').merge('reason' => 'meta change: libdw1 (md5sum)')))
    page = render(collapsed)

    assert_includes page, '<details class="reason"><summary>meta change</summary>libdw1 (md5sum)</details>'
    assert_includes page, '<span class="reason">meta change: ffmpeg-8-libavcodec-devel &lt;8.1.3&gt;</span>'
    assert_includes page, '<span class="reason">new build</span>'
  end

  it 'flags a package with uninstallable rpms' do
    ffmpeg = state.dig('packages', 'ffmpeg-8').merge('uninstallable' => ['libavcodec62-32bit: nothing provides liboapv.so.1'])
    flagged = state.merge('packages' => state.fetch('packages').merge('ffmpeg-8' => ffmpeg))
    page = render(flagged)

    assert_includes page, '<details class="reason problem"><summary>not installable</summary><div>libavcodec62-32bit: nothing provides liboapv.so.1</div></details>'
    assert_equal 1, page.scan('not installable</summary>').size
  end

  it 'escapes hostile state in text, attributes and urls' do
    payload = %("'><script>alert(1)</script><%= 7 * 7 %>)
    hostile = state.merge('run' => payload, 'generated_at' => payload, 'key' => { 'id' => payload, 'fingerprint' => payload })
    hostile['packages'] = state.fetch('packages').merge(payload => { 'status' => payload, 'reason' => payload, 'version' => payload, 'built_at' => payload })
    hostile['files'] = state.fetch('files').merge("x86_64/#{payload}.rpm" => { 'package' => payload, 'size' => payload })
    html = render(hostile)

    refute_includes html, '<script>alert'
    refute_includes html, %("'>)
    assert_includes html, '&quot;&#39;&gt;&lt;script&gt;alert(1)&lt;/script&gt;&lt;%= 7 * 7 %&gt;'
  end

  it 'renders search and social metadata' do
    assert_includes html, '<link rel="canonical" href="https://packman.example.org/">'
    assert_includes html, '<meta property="og:url" content="https://packman.example.org/">'
    assert_includes html, '<meta property="og:site_name" content="packman-nova">'
    assert_includes html, '<link rel="icon" href="favicon.svg" type="image/svg+xml">'
    assert_includes html, '<link rel="apple-touch-icon" href="apple-touch-icon.png">'
    assert_includes html, '<link rel="manifest" href="site.webmanifest">'
    assert_includes html, '<meta property="og:image" content="https://packman.example.org/og-image.png">'
    assert_includes html, '<meta name="twitter:card" content="summary_large_image">'
    data = ::JSON.parse(html[%r{<script type="application/ld\+json">(.*?)</script>}, 1])

    assert_equal 'SoftwareSourceCode', data['@type']
    assert_equal 'https://github.com/olegantonyan/packman-nova', data['codeRepository']
    assert_equal '2026-09-29T08:15:42Z', data['dateModified']
  end

  it 'escapes markup in the structured data' do
    page = ::PackmanNova::Site::Generator.new(config: site_config, states: { 'opensuse_tumbleweed' => state.merge('generated_at' => '</script><b>') }, logger: null_logger)
                                         .render('index.html')

    refute_includes page, '</script><b>'
    assert_includes page, '\u003c/script\u003e\u003cb\u003e'
  end

  it 'renders the sitemap and robots.txt' do
    sitemap = generator.render('sitemap.xml')

    assert_includes sitemap, '<loc>https://packman.example.org/</loc>'
    assert_includes sitemap, '<lastmod>2026-09-29T08:15:42Z</lastmod>'
    assert_includes generator.render('robots.txt'), 'Sitemap: https://packman.example.org/sitemap.xml'
  end

  it 'renders llms.txt' do
    llms = generator.render('llms.txt')

    assert llms.start_with?("# packman-nova\n\n> Full multimedia codecs")
    assert_includes llms, '- [openSUSE Tumbleweed](https://packman.example.org/opensuse_tumbleweed/essentials/packman-nova.repo): `sudo zypper ar -f -p 80 '
    assert_includes llms, '- [Full text](https://packman.example.org/llms-full.txt)'
    assert_includes llms, '- [Source code](https://github.com/olegantonyan/packman-nova)'
    refute_includes llms, 'Leap'
  end

  it 'renders llms-full.txt' do
    full = generator.render('llms-full.txt')

    assert full.start_with?('# packman-nova: Packman codecs for openSUSE Tumbleweed and Leap 16')
    assert_includes full, "```\nsudo zypper ar -f -p 80 "
    assert_includes full, 'sudo zypper dup --from packman-nova-essentials --allow-vendor-change'
    state.fetch('packages').each do |name, entry|
      assert_includes full, "| #{name} | #{entry.fetch('version')}-#{entry.fetch('release')} |"
    end
    assert_includes full, '[openSUSE:Factory/vlc](https://build.opensuse.org/package/show/openSUSE:Factory/vlc)'
    assert_includes full, 'Fingerprint: 0A1B 2C3D 4E5F 6071 8293 A4B5 C6D7 E8F9 3F1C 2A9B'
    assert_equal 2, full.scan('Not published yet.').size
  end

  it 'is self-contained' do
    assert_includes html, 'light-dark('
    assert_includes html, 'id="theme-toggle"'
    refute_match(/<link rel="stylesheet"|<script src/, html)
    refute_match(/<!--/, html)
  end

  it 'renders without a key' do
    html = render(state.except('key'))

    assert_includes html, 'No signing key recorded'
  end

  it 'renders a switchable panel per distro' do
    assert_includes html, '<button type="button" role="tab" data-distro="opensuse_leap_16.0" aria-controls="opensuse_leap_16.0">openSUSE Leap 16.0</button>'
    assert_includes html, '<div class="distro" id="opensuse_tumbleweed" role="tabpanel">'
    assert_includes html, '<div class="distro" id="opensuse_leap_16.1" role="tabpanel">'
    assert_equal 2, html.scan('Not published yet.').size
    assert_includes html, 'id="opensuse_tumbleweed-pkg-ffmpeg-8"'
    assert_includes html, 'href="https://packman.example.org/opensuse_tumbleweed/essentials/packages.json"'
  end

  it 'writes every site file' do
    with_tmpdir do |dir|
      paths = generator.write(dir)

      names = %w[favicon.svg favicon.ico apple-touch-icon.png icon-192.png icon-512.png og-image.png site.webmanifest robots.txt sitemap.xml llms.txt llms-full.txt index.html]

      assert_equal(names.map { |name| ::File.join(dir, name) }, paths)
      assert_equal html, ::File.read(::File.join(dir, 'index.html'))
      assert_includes ::File.read(::File.join(dir, 'favicon.svg')), '<svg'
      assert_equal ::File.binread(::File.join(::PackmanNova::Site::Generator::ASSETS_DIR, 'og-image.png')), ::File.binread(::File.join(dir, 'og-image.png'))
    end
  end

  it 'renders the web manifest' do
    manifest = ::JSON.parse(generator.render('site.webmanifest'))

    assert_equal 'packman-nova', manifest['short_name']
    assert_equal 'https://packman.example.org/', manifest['start_url']
    assert_equal(%w[icon-192.png icon-512.png], manifest['icons'].map { |icon| icon['src'] })
  end

  it 'ships every site asset' do
    ::PackmanNova::Repo::Layout::SITE_ASSETS.each do |name|
      assert_path_exists ::File.join(::PackmanNova::Site::Generator::ASSETS_DIR, name)
    end
  end

  it 'writes the packages document of one distro' do
    with_tmpdir do |dir|
      path = ::PackmanNova::Site::Generator.write_packages(::File.join(dir, 'packages.json'), state)

      assert_equal({ 'generated_at' => state.fetch('generated_at'), 'packages' => state.fetch('packages') }, ::JSON.parse(::File.read(path)))
    end
  end
end
