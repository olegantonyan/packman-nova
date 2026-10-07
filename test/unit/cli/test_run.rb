# frozen_string_literal: true

require 'test_helper'

module RunFakes
  Report = ::Data.define(:failed) do
    def log(_logger)
      self
    end
  end

  Diff = ::Data.define(:to_add, :to_replace, :to_remove)

  class Recorder
    attr_reader :calls

    def initialize(result = nil, &block)
      @result = result
      @block = block
      @calls = []
    end

    def call(**arguments)
      calls << arguments
      @block ? @block.call : @result
    end

    def uninstallable
      {}
    end
  end
end

describe ::PackmanNova::Cli::Run do
  let(:root) { ::Dir.mktmpdir('packman-nova-run-') }
  let(:config) { load_config(env: { 'PACKMAN_NOVA_WORKDIR' => root }) }
  let(:log) { string_logger }
  let(:sync) { ::RunFakes::Recorder.new(::RunFakes::Report.new(failed: {})) }
  let(:build) { ::RunFakes::Recorder.new(1) }
  let(:publisher) { ::RunFakes::Recorder.new(::RunFakes::Diff.new(to_add: %w[a b], to_replace: [], to_remove: %w[c])) }

  before do
    ::PackmanNova::Utils::JsonFile.write(
      ::File.join(root, 'state', 'last-build.json'),
      { 'run' => 4, 'release' => '1699.4.nova.1', 'built' => %w[fdk-aac vlc],
        'packages' => { 'fdk-aac' => { 'code' => 'succeeded' }, 'vlc' => { 'code' => 'failed' }, 'x265' => { 'code' => 'succeeded' } } }
    )
  end

  after { ::FileUtils.rm_rf(root) }

  def run_command(publisher: self.publisher, sync: self.sync, **options)
    ::PackmanNova::Cli::Run.new(config:, logger: log.first, options:, sync:, build:, publisher:).call
  end

  def summary
    log.last.string[/run summary: (.*)$/, 1]
  end

  it 'syncs, builds without a second sync, then publishes' do
    assert_equal 1, run_command(provider: 's3')
    assert_equal [{}], sync.calls
    assert_equal [{ sync: false }], build.calls
    assert_equal [{ provider: 's3' }], publisher.calls
    assert_equal 'run 4, release 1699.4.nova.1: built 2 of 3, 1 failed (vlc); published 2 added, 0 replaced, 1 removed', summary
  end

  it 'skips publishing on request' do
    run_command(publish: false)

    assert_empty publisher.calls
    assert_equal 'run 4, release 1699.4.nova.1: built 2 of 3, 1 failed (vlc); publish skipped', summary
  end

  it 'exits 0 with failed packages when told not to fail on them' do
    assert_equal 0, run_command(fail_on_failed_packages: false)
  end

  it 'exits 2 on a publish failure and reports sync failures' do
    failing = ::RunFakes::Recorder.new { raise ::PackmanNova::PublishError, 'bucket gone' }
    report = ::RunFakes::Report.new(failed: { 'packman-nova-keyring' => 'missing key' })

    assert_equal 2, run_command(publisher: failing, sync: ::RunFakes::Recorder.new(report))
    assert_includes summary, 'sync failed: packman-nova-keyring; publish failed: bucket gone'
  end
end
