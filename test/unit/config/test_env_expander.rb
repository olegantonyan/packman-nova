# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Config::EnvExpander do
  let(:expander) { ::PackmanNova::Config::EnvExpander.new(env: { 'A' => 'alpha', 'EMPTY' => '' }) }

  it 'expands variables inside strings of nested structures' do
    expanded = expander.expand({ key: 'x-${A}-y', list: ['${A}', 1], nested: { flag: true } })

    assert_equal({ key: 'x-alpha-y', list: ['alpha', 1], nested: { flag: true } }, expanded)
  end

  it 'replaces unknown variables with empty strings' do
    assert_equal '/', expander.expand('${MISSING}/')
  end

  it 'records used and missing variable names' do
    expander.expand(['${A}', '${EMPTY}', '${MISSING}', '${A}'])

    assert_equal %w[A EMPTY MISSING], expander.used_names
    assert_equal %w[EMPTY MISSING], expander.missing_names
  end

  it 'leaves $VAR without braces alone' do
    assert_equal '$A', expander.expand('$A')
  end
end
