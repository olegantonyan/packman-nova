# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sync::Report do
  let(:report) { ::PackmanNova::Sync::Report.new }

  def outcome(name, status, detail = nil)
    ::PackmanNova::Sync::Outcome.new(name: name, status: status, record: {}, detail: detail)
  end

  it 'has no drift when everything is unchanged' do
    report.add(outcome('vlc', :unchanged))
    report.track('Tumbleweed snapshot', previous: '20260924', current: '20260924')

    refute_predicate report, :drift?
    refute_predicate report, :failed?
  end

  it 'counts changed, removed packages and changed tracked values as drift' do
    changed = ::PackmanNova::Sync::Report.new.tap { |r| r.add(outcome('vlc', :changed, 'new')) }
    removed = ::PackmanNova::Sync::Report.new.tap { |r| r.remove('old') }
    snapshot = ::PackmanNova::Sync::Report.new.tap { |r| r.track('Tumbleweed snapshot', previous: '20260920', current: '20260924') }

    assert_equal [true, true, true], [changed, removed, snapshot].map(&:drift?)
  end

  it 'ignores untracked values' do
    report.track('Tumbleweed snapshot', previous: '20260920', current: nil)

    refute_predicate report, :drift?
  end

  it 'renders a human-readable summary' do
    report.add(outcome('ffmpeg-8', :changed, 'srcmd5 a -> b'))
    report.add(outcome('vlc', :unchanged))
    report.fail('packman-nova-keyring', 'local source packman-nova.key not found')
    report.remove('SVT-AV1')
    report.track('Tumbleweed snapshot', previous: nil, current: '20260924')

    assert_equal [
      'sync summary', 'changed (1):', '  ffmpeg-8: srcmd5 a -> b', 'unchanged (1)', 'removed (1): SVT-AV1',
      'failed (1):', '  packman-nova-keyring: local source packman-nova.key not found', 'Tumbleweed snapshot: (none) -> 20260924'
    ], report.lines
  end
end
