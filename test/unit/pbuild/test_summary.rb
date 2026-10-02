# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Pbuild::Summary do
  let(:record) do
    {
      'run' => 3, 'release' => '1699.3.nova.1', 'codes' => { 'failed' => 1, 'succeeded' => 1 }, 'built' => ['vlc'],
      'packages' => {
        'fdk-aac' => { 'code' => 'succeeded', 'rpms' => %w[a b], 'duration_sec' => 75, 'reason' => 'new build' },
        'vlc' => { 'code' => 'failed', 'rpms' => [], 'duration_sec' => 9, 'reason' => nil }
      }
    }
  end

  it 'renders a table and a footer' do
    assert_equal <<~TEXT, ::PackmanNova::Pbuild::Summary.new(record: record).to_s
      package  code       rpms  time   reason
      fdk-aac  succeeded  2     1m15s  new build
      vlc      failed     0     9s     -
      run 3, release 1699.3.nova.1, built 1 of 2: failed 1, succeeded 1
    TEXT
  end

  it 'shortens long reasons' do
    record['packages']['fdk-aac']['reason'] = "meta change: #{'x' * 200}"
    line = ::PackmanNova::Pbuild::Summary.new(record: record).to_s.lines[1]

    assert_equal "fdk-aac  succeeded  2     1m15s  meta change: #{'x' * 84}...\n", line
  end

  it 'lists failed packages' do
    assert_equal ['vlc'], ::PackmanNova::Pbuild::Summary.failed_packages(record)
  end
end
