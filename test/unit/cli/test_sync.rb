# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Cli::Sync, :sync do
  let(:server) { ::HttpStubServer.new }
  let(:dir) { ::Dir.mktmpdir('packman-nova-cli-sync-') }
  let(:config) { sync_config(dir, server) }
  let(:packages_dir) { config.packages_dir }

  before do
    stub_common(server)
    stub_obs_package(server, project: 'openSUSE:Factory', package: 'ffmpeg-8', srcmd5: 'a' * 32, files: { 'ffmpeg-8.spec' => "Name: ffmpeg-8\n" })
    server.on('/obs/source/openSUSE:Factory/nope?expand=1', status: 404)
  end

  after do
    server.stop
    ::FileUtils.rm_rf(dir)
  end

  def run_sync(**options)
    logger, io = string_logger(level: ::Logger::INFO)
    code = ::PackmanNova::Cli::Sync.new(config:, logger:, options:).call
    [code, io.string]
  end

  it 'exits 0 after a successful sync and prints the summary' do
    code, output = run_sync(packages: ['ffmpeg-8'])

    assert_equal 0, code
    assert_match(/changed \(1\):\n.*ffmpeg-8: new/, output)
  end

  it 'exits 2 when --check finds drift and 0 when it finds none' do
    assert_equal 2, run_sync(packages: ['ffmpeg-8'], check: true).first
    run_sync(packages: ['ffmpeg-8'])

    assert_equal 0, run_sync(packages: ['ffmpeg-8'], check: true).first
  end

  it 'exits 1 when a package fails' do
    code, output = run_sync(packages: %w[ffmpeg-8 xine-lib])

    assert_equal 1, code
    assert_match(/failed \(1\):\n.*xine-lib/, output)
  end
end
