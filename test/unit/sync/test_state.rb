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
    data = { 'schema' => 1, 'tumbleweed_snapshot' => '20260924', 'packages' => { 'vlc' => { 'srcmd5' => 'abc' } } }
    state.save(data)

    assert_equal data, state.load
    assert_equal ::File.join(dir, 'state', 'sync.json'), state.path
  end

  it 'rejects data without the required keys' do
    assert_raises(::PackmanNova::Error) { state.save({ 'schema' => 1 }) }
  end
end
