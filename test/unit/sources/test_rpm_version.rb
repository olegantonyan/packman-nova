# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sources::RpmVersion do
  def version(string)
    ::PackmanNova::Sources::RpmVersion.new(string)
  end

  it 'compares numeric segments numerically' do
    assert_operator version('6.1.10'), :>, version('6.1.3')
    assert_operator version('1699.1.pm.10'), :>, version('1699.1.pm.9')
  end

  it 'treats a longer version as newer and numbers as newer than letters' do
    assert_operator version('1.0.1'), :>, version('1.0')
    assert_operator version('1.0.1'), :>, version('1.0.a')
  end

  it 'considers equal segment lists equal' do
    assert_equal 0, version('1.2_3') <=> version('1.2.3')
  end
end
