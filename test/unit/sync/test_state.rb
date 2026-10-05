# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sync::State do
  let(:dir) { ::Dir.mktmpdir('packman-nova-state-') }
  let(:state) { ::PackmanNova::Sync::State.new(workdir: ::PackmanNova::Workdir.new(root: dir)) }

  after { ::FileUtils.rm_rf(dir) }

  it 'returns an empty state when the file does not exist' do
    assert_equal({ 'schema' => 1, 'packages' => {} }, state.load)
  end

  it 'round-trips the state through state/sync.json' do
    data = { 'schema' => 1, 'distro_snapshot' => '20260924', 'packages' => { 'vlc' => { 'srcmd5' => 'abc' } } }
    state.save(data)

    assert_equal data, state.load
    assert_equal ::File.join(dir, 'state', 'sync.json'), state.path
  end

  it 'reads flags and clears rebuild_all_required keeping other keys' do
    state.save({ 'schema' => 1, 'rebuild_all_required' => true, 'distro_snapshot' => '20260924', 'packages' => { 'fdk-aac' => { 'kind' => 'native' } } })

    assert_predicate state, :rebuild_all_required?
    assert_equal '20260924', state.snapshot
    state.clear_rebuild_all!

    refute_predicate state, :rebuild_all_required?
    assert_equal({ 'fdk-aac' => { 'kind' => 'native' } }, state.packages)
  end

  it 'leaves a missing file missing when clearing the rebuild flag' do
    state.clear_rebuild_all!

    refute_predicate state, :rebuild_all_required?
    assert_empty state.packages
    refute_path_exists state.path
  end

  it 'rejects data without the required keys' do
    assert_raises(::PackmanNova::Error) { state.save({ 'schema' => 1 }) }
  end
end
