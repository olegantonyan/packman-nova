# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Pbuild::Table do
  it 'aligns columns and prints nil as a dash' do
    table = ::PackmanNova::Pbuild::Table.new(headers: %w[package code rpms], rows: [['fdk-aac', 'succeeded', 3], ['vlc', nil, 0]])

    assert_equal "package  code       rpms\nfdk-aac  succeeded  3\nvlc      -          0\n", table.to_s
  end
end
