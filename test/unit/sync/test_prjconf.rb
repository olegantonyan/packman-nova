# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sync::Prjconf, :sync do
  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-prjconf-') }
  let(:config) { sync_config(dir, server) }
  let(:workdir) { config.workdir }

  def prjconf(offline: false)
    http = ::PackmanNova::Utils::Http.new(logger: null_logger, timeout_sec: 5, retries: 0, offline:)
    downloader = ::PackmanNova::Sources::Downloader.new(http:, logger: null_logger)
    ::PackmanNova::Sync::Prjconf.new(config:, workdir:, downloader:, logger: null_logger)
  end

  after do
    server.stop
    ::FileUtils.rm_rf(dir)
  end

  it 'writes the Factory config and the local macros without Release lines' do
    server.on('/prjconf', body: ::SyncSpec::FACTORY_PRJCONF)
    result = prjconf.call

    assert_equal ::SyncSpec::FACTORY_PRJCONF, ::File.read(prjconf.factory_path)
    assert_equal "Prefer: foo\n", ::File.read(workdir.config_file)
    assert_equal [md5_of(::SyncSpec::FACTORY_PRJCONF), md5_of("Prefer: foo\n")], [result.factory_md5, result.local_md5]
  end

  it 'falls back to the committed base config when offline and nothing was synced before' do
    prjconf(offline: true).call

    assert_equal "Repotype: rpm-md\n", ::File.read(prjconf.factory_path)
  end

  it 'keeps the previously synced Factory config when the fetch fails' do
    server.on('/prjconf', body: ::SyncSpec::FACTORY_PRJCONF)
    prjconf.call
    server.on('/prjconf', status: 404)
    server.on('/prjconf', status: 404)

    assert_equal md5_of(::SyncSpec::FACTORY_PRJCONF), prjconf.call.factory_md5
  end

  it 'writes nothing when write: false' do
    server.on('/prjconf', body: ::SyncSpec::FACTORY_PRJCONF)
    prjconf.call(write: false)

    refute_path_exists workdir.config_file
    refute_path_exists prjconf.factory_path
  end
end
