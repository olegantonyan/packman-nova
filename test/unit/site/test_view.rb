# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Site::View do
  let(:view) { ::PackmanNova::Site::View.wrap('title' => 'x', 'key' => nil, 'rows' => [{ 'name' => 'a' }]) }

  it 'exposes keys as readers' do
    assert_equal 'x', view.title
    assert_nil view.key
    assert_equal 'a', view.rows.first.name
  end

  it 'raises on an unknown key' do
    assert_raises(::NoMethodError) { view.titel }
  end

  it 'is immutable' do
    assert_predicate view, :frozen?
  end
end
