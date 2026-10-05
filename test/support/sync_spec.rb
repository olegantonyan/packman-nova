# frozen_string_literal: true

require 'fileutils'
require 'yaml'

class SyncSpec < ::PackmanNovaSpec
  SNAPSHOT_BODY = "openSUSE - openSUSE-20260924-x86_64-Build6.115\nopenSUSE-20260924-x86_64-Build6.115\n1\n"
  FACTORY_PRJCONF = "Repotype: rpm-md\nMacros:\n%dist_x 1\n:Macros\n"

  def tarball
    ::File.binread(fixture_path('sync', 'hello-1.0.tar.gz'))
  end

  def sha256_of(content)
    ::Digest::SHA256.hexdigest(content)
  end

  def md5_of(content)
    ::PackmanNova::Utils::Digest.md5_string(content)
  end

  def sync_config(dir, server)
    path = write_file(::File.join(dir, 'config.yml'), ::YAML.dump(sync_settings(dir, server)))
    load_config(path:, env: { 'PACKMAN_NOVA_WORKDIR' => nil, 'PACKMAN_NOVA_CONTAINER_RUNTIME' => nil })
  end

  def sync_settings(dir, server)
    {
      'workdir' => ::File.join(dir, 'wd'),
      'distro' => { 'snapshot_url' => server.url('/media') },
      'prjconf' => {
        'base_url' => server.url('/prjconf'), 'base_fallback' => write_file(::File.join(dir, 'fallback.conf'), "Repotype: rpm-md\n"),
        'local' => write_file(::File.join(dir, 'macros.conf'), "Release: %{suse_version}.<CI_CNT>\nPrefer: foo\n")
      },
      'sources' => source_settings(server),
      'repository' => { 'public_url' => server.url('/pub') }
    }
  end

  def source_settings(server)
    {
      'obs_api' => server.url('/obs'),
      'http' => { 'timeout_sec' => 5, 'retries' => 0 }
    }
  end

  def write_file(path, content)
    ::FileUtils.mkdir_p(::File.dirname(path))
    ::File.binwrite(path, content)
    path
  end

  def write_package(packages_dir, manifest, files = {})
    dir = ::File.join(packages_dir, manifest.fetch('name'))
    write_file(::File.join(dir, 'package.yml'), ::YAML.dump(manifest))
    files.each { |name, content| write_file(::File.join(dir, name), content) }
    dir
  end

  def obs_listing(srcmd5, files)
    entries = files.map { |name, content| %(  <entry name="#{name}" md5="#{md5_of(content)}" size="#{content.bytesize}" mtime="1"/>) }
    %(<directory name="x" srcmd5="#{srcmd5}">\n#{entries.join("\n")}\n</directory>\n)
  end

  def stub_obs_package(server, project:, package:, srcmd5:, files:)
    server.on("/obs/source/#{project}/#{package}?expand=1", body: obs_listing(srcmd5, files))
    files.each { |name, content| server.on("/obs/source/#{project}/#{package}/#{name}?rev=#{srcmd5}", body: content) }
  end

  def stub_common(server)
    server.on('/media', body: SNAPSHOT_BODY).on('/prjconf', body: FACTORY_PRJCONF)
  end
end

::Minitest::Spec.register_spec_type(::SyncSpec) { |_desc, *tags| tags.include?(:sync) }
