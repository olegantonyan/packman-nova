# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Pbuild::SyncState do
  it 'reads flags and clears rebuild_all_required keeping other keys' do
    with_tmpdir do |dir|
      path = ::File.join(dir, 'sync.json')
      ::File.write(path, '{"schema":1,"rebuild_all_required":true,"tumbleweed_snapshot":"20260924","packages":{"fdk-aac":{"kind":"native"}}}')
      state = ::PackmanNova::Pbuild::SyncState.new(path: path)

      assert_predicate state, :rebuild_all_required?
      assert_equal '20260924', state.tumbleweed_snapshot
      assert_equal({ 'fdk-aac' => { 'kind' => 'native' } }, state.packages)
      state.clear_rebuild_all!

      refute_predicate state, :rebuild_all_required?
      assert_equal({ 'fdk-aac' => { 'kind' => 'native' } }, ::JSON.parse(::File.read(path))['packages'])
    end
  end

  it 'tolerates a missing file' do
    with_tmpdir do |dir|
      state = ::PackmanNova::Pbuild::SyncState.new(path: ::File.join(dir, 'sync.json'))
      state.clear_rebuild_all!

      refute_predicate state, :rebuild_all_required?
      assert_empty state.packages
      refute_path_exists ::File.join(dir, 'sync.json')
    end
  end
end
