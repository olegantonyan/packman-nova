# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Upstream::VersionCompare do
  def compare(left, right)
    ::PackmanNova::Upstream::VersionCompare.compare(left, right)
  end

  it 'compares numeric segments numerically, ignoring leading zeros' do
    assert_equal 1, compare('1.28.10', '1.28.9')
    assert_equal 1, compare('8.057.00', '8.053.00')
    assert_equal 0, compare('8.053.00', '8.53.0')
  end

  it 'treats separators alike and prefers more segments' do
    assert_equal 0, compare('5.15.285+5.15.010.0', '5.15.285-5.15.010.0')
    assert_equal 1, compare('2.0.1', '2.0')
    assert_equal(-1, compare('0.2', '0.2.1'))
  end

  it 'ranks numbers above letters' do
    assert_equal 1, compare('1.0.1', '1.0.a')
    assert_equal 1, compare('1.0b', '1.0a')
  end

  it 'picks the maximum' do
    assert_equal '26.07.0', ::PackmanNova::Upstream::VersionCompare.max(%w[2.4.0 26.07.0 2.10.1])
  end
end
