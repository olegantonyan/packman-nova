# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Pbuild::SyncRunner do
  let(:config) { load_config(env: { 'PACKMAN_NOVA_WORKDIR' => '/tmp/packman-nova-sync-runner' }) }

  it 'calls an injected sync' do
    assert_equal :done, ::PackmanNova::Pbuild::SyncRunner.new(config: config, logger: null_logger, sync: -> { :done }).call
  end

  it 'runs the real sync entry point and logs its report' do
    skip 'Sync is not implemented yet' unless ::PackmanNova::Pbuild::SyncRunner.available?

    report = ::Struct.new(:lines, :failed?).new(['sync summary', 'changed (0)'], true)
    received = []
    fake = ::Object.new
    fake.define_singleton_method(:call) do |**kwargs|
      received << kwargs
      report
    end
    logger, io = string_logger

    ::PackmanNova::Sync.define_singleton_method(:new) { |**| fake }
    begin
      ::PackmanNova::Pbuild::SyncRunner.new(config: config, logger: logger).call
    ensure
      ::PackmanNova::Sync.singleton_class.send(:remove_method, :new)
    end

    assert_equal [{ packages: nil, check_only: false, update_checksums: false }], received
    assert_match(/\[I\] sync summary/, io.string)
    assert_match(/\[W\] sync failed for some packages/, io.string)
  end
end
