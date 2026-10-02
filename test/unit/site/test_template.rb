# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Site::Template do
  def render(source, assigns = {})
    ::PackmanNova::Site::Template.new(source: source, name: 'snippet').render(assigns)
  end

  it 'renders assigns' do
    assert_equal 'a &lt;b&gt;', render('{{ value | escape }}', 'value' => 'a <b>')
  end

  it 'raises on an undefined variable' do
    error = assert_raises(::PackmanNova::Error) { render('{{ missing }}') }

    assert_match(/snippet: .*undefined variable missing/, error.message)
  end

  it 'raises on an undefined nested key' do
    assert_raises(::PackmanNova::Error) { render('{{ key.id }}', 'key' => {}) }
  end

  it 'raises on an undefined filter' do
    assert_raises(::PackmanNova::Error) { render('{{ value | shout }}', 'value' => 'x') }
  end

  it 'raises on a syntax error' do
    assert_raises(::PackmanNova::Error) { render('{% if value %}') }
  end

  it 'loads bundled templates' do
    assert_includes ::PackmanNova::Site::Template.read('style.css'), 'prefers-color-scheme: dark'
  end
end
