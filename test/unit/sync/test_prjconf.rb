# frozen_string_literal: true

require 'test_helper'
require_relative 'sync_fixture'

describe ::PackmanNova::Sync::Prjconf do
  include ::SyncFixture

  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-prjconf-') }
  let(:config) { sync_config(dir, server) }
  let(:workdir) { config.workdir }

  def prjconf(offline: false)
    http = ::PackmanNova::Utils::Http.new(logger: null_logger, timeout_sec: 5, retries: 0, offline: offline)
    downloader = ::PackmanNova::Sources::Downloader.new(http: http, logger: null_logger, offline: offline)
    ::PackmanNova::Sync::Prjconf.new(config: config, workdir: workdir, downloader: downloader, logger: null_logger)
  end

  after do
    server.stop
    ::FileUtils.rm_rf(dir)
  end

  it 'writes the Factory config and the local macros without Release lines' do
    server.on('/prjconf', body: ::SyncFixture::FACTORY_PRJCONF)
    result = prjconf.call

    assert_equal ::SyncFixture::FACTORY_PRJCONF, ::File.read(prjconf.factory_path)
    assert_equal "Prefer: foo\n", ::File.read(workdir.config_file)
    assert_equal [md5_of(::SyncFixture::FACTORY_PRJCONF), md5_of("Prefer: foo\n")], [result.factory_md5, result.local_md5]
  end

  it 'caches the fetched Factory config by md5' do
    server.on('/prjconf', body: ::SyncFixture::FACTORY_PRJCONF)
    prjconf.call

    assert ::File.file?(::File.join(workdir.prjconf_cache_dir, "factory-#{md5_of(::SyncFixture::FACTORY_PRJCONF)}.conf"))
  end

  it 'falls back to the committed base config when offline and nothing was synced before' do
    result = prjconf(offline: true).call

    assert_equal "Repotype: rpm-md\n", ::File.read(prjconf.factory_path)
    assert_equal config.prjconf.base_fallback, result.factory_source
  end

  it 'keeps the previously synced Factory config when the fetch fails' do
    server.on('/prjconf', body: ::SyncFixture::FACTORY_PRJCONF)
    prjconf.call
    server.on('/prjconf', status: 404)
    server.on('/prjconf', status: 404)

    assert_equal md5_of(::SyncFixture::FACTORY_PRJCONF), prjconf.call.factory_md5
  end

  it 'writes nothing when write: false' do
    server.on('/prjconf', body: ::SyncFixture::FACTORY_PRJCONF)
    prjconf.call(write: false)

    refute_path_exists workdir.config_file
    refute_path_exists prjconf.factory_path
  end
end
