# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Site::Template do
  def render(source, assigns = {})
    ::PackmanNova::Site::Template.new(source: source, name: 'snippet').render(assigns)
  end

  it 'renders escaped assigns' do
    assert_equal 'a &lt;b&gt; &quot;c&quot; &#39;d&#39; &amp;', render('<%= h value %>', 'value' => %(a <b> "c" 'd' &))
  end

  it 'renders nested hashes and arrays' do
    assert_equal 'x:1,y:2,', render('<% rows.each do |row| %><%= row.name %>:<%= row.size %>,<% end %>', 'rows' => [{ 'name' => 'x', 'size' => 1 }, { 'name' => 'y', 'size' => 2 }])
  end

  it 'renders nil as empty' do
    assert_equal '[]', render('[<%= h value %>]', 'value' => nil)
  end

  it 'does not evaluate template syntax inside values' do
    payload = "<%= 7 * 7 %> \#{7 * 7} {{ 7 | times: 7 }}"

    assert_equal payload, render('<%= value %>', 'value' => payload)
  end

  it 'raises on an undefined variable' do
    error = assert_raises(::PackmanNova::Error) { render('<%= missing %>') }

    assert_match(/snippet: .*missing/, error.message)
  end

  it 'raises on an undefined nested key' do
    assert_raises(::PackmanNova::Error) { render('<%= key.id %>', 'key' => { 'fingerprint' => 'x' }) }
  end

  it 'raises on a syntax error' do
    assert_raises(::PackmanNova::Error) { render('<%= ) %>') }
  end

  it 'escapes every output in the index template except the stylesheet' do
    outputs = ::PackmanNova::Site::Template.read(::PackmanNova::Site::Generator::INDEX_TEMPLATE).scan(/<%=\s*(.*?)\s*-?%>/).flatten

    refute_empty outputs
    assert_empty(outputs.reject { |expression| expression == 'style' || expression.start_with?('h ') })
  end

  it 'loads bundled templates' do
    assert_includes ::PackmanNova::Site::Template.read('style.css'), 'light-dark('
  end
end
