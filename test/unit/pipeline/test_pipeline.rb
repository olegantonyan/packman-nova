# frozen_string_literal: true

require 'test_helper'

module PipelineFakes
  Report = ::Data.define(:failed) do
    def lines
      ['sync summary']
    end

    def failed?
      !failed.empty?
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
  end

  Records = ::Data.define(:last)

  class Run < ::PackmanNova::Cli::Run
    def initialize(pipeline:, **)
      super(**)
      @fake_pipeline = pipeline
    end

    private

    def pipeline
      @fake_pipeline
    end
  end
end

describe ::PackmanNova::Pipeline do
  let(:config) { load_config(env: { 'PACKMAN_NOVA_WORKDIR' => '/w' }) }
  let(:record) do
    { 'run' => 4, 'release' => '1699.4.nova.1', 'built' => %w[fdk-aac vlc],
      'packages' => { 'fdk-aac' => { 'code' => 'succeeded' }, 'vlc' => { 'code' => 'failed' }, 'x265' => { 'code' => 'succeeded' } } }
  end
  let(:sync) { ::PipelineFakes::Recorder.new(::PipelineFakes::Report.new(failed: {})) }
  let(:build) { ::PipelineFakes::Recorder.new(1) }
  let(:publisher) { ::PipelineFakes::Recorder.new(::PipelineFakes::Diff.new(to_add: %w[a b], to_replace: [], to_remove: %w[c])) }

  def pipeline(**overrides)
    ::PackmanNova::Pipeline.new(
      config: config, logger: null_logger, sync: sync, build: build, publisher: publisher, build_record: ::PipelineFakes::Records.new(last: record), **overrides
    )
  end

  it 'syncs, builds without a second sync, then publishes' do
    result = pipeline.call(provider: 'localfs')

    assert_equal [{ packages: nil, check_only: false, update_checksums: false }], sync.calls
    assert_equal [{ sync: false }], build.calls
    assert_equal [{ provider: 'localfs' }], publisher.calls
    assert_equal %w[vlc], result.failed_packages
    assert_predicate result, :packages_failed?
    refute_predicate result, :publish_failed?
    assert_equal 'run 4, release 1699.4.nova.1: built 2 of 3, 1 failed (vlc); published 2 added, 0 replaced, 1 removed', result.summary
  end

  it 'skips publishing on request' do
    result = pipeline.call(publish: false)

    assert_empty publisher.calls
    assert_equal 'run 4, release 1699.4.nova.1: built 2 of 3, 1 failed (vlc); publish skipped', result.summary
  end

  it 'captures a publish failure and reports sync failures' do
    failing = ::PipelineFakes::Recorder.new { raise ::PackmanNova::PublishError, 'bucket gone' }
    report = ::PipelineFakes::Report.new(failed: { 'packman-nova-keyring' => 'missing key' })
    result = pipeline(publisher: failing, sync: ::PipelineFakes::Recorder.new(report)).call

    assert_predicate result, :publish_failed?
    assert_equal %w[packman-nova-keyring], result.sync_failed
    assert_includes result.summary, 'sync failed: packman-nova-keyring; publish failed: bucket gone'
  end
end

describe ::PackmanNova::Cli::Run do
  def result(failed: [], publish_error: nil)
    ::PackmanNova::Pipeline::Result.new(
      sync_failed: [], record: {}, failed_packages: failed, published: true, diff: ::PipelineFakes::Diff.new(to_add: [], to_replace: [], to_remove: []),
      publish_error: publish_error
    )
  end

  def exit_code(result, **options)
    pipeline = ::PipelineFakes::Recorder.new(result)
    code = ::PipelineFakes::Run.new(pipeline: pipeline, config: nil, logger: null_logger, options: options).call
    [code, pipeline.calls]
  end

  it 'exits 0 when everything succeeded and passes the options through' do
    assert_equal [0, [{ publish: false, provider: 's3' }]], exit_code(result, publish: false, provider: 's3')
  end

  it 'exits 1 when a package failed although publishing succeeded' do
    assert_equal 1, exit_code(result(failed: %w[vlc])).first
  end

  it 'exits 0 with failed packages when told not to fail on them' do
    assert_equal 0, exit_code(result(failed: %w[vlc]), fail_on_failed_packages: false).first
  end

  it 'exits 2 when publishing failed' do
    assert_equal 2, exit_code(result(failed: %w[vlc], publish_error: ::PackmanNova::PublishError.new('x'))).first
  end
end
