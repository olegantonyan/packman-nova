# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Pbuild::ResultParser do
  let(:parser) { ::PackmanNova::Pbuild::ResultParser.parse(::File.read(fixture_path('pbuild', 'result-terse.txt'))) }

  it 'groups package names by code' do
    assert_equal({ 'succeeded' => %w[fdk-aac libx264:x264], 'failed' => ['vlc'], 'unresolvable' => ['ffmpeg-6'], 'excluded' => [] }, parser.packages_by_code)
  end

  it 'keeps the counts, including codes without listed names' do
    assert_equal({ 'succeeded' => 2, 'failed' => 1, 'unresolvable' => 1, 'excluded' => 3 }, parser.counts)
  end

  it 'maps names to codes' do
    assert_equal 'failed', parser.code_for('vlc')
    assert_nil parser.code_for('nope')
    assert_equal 'succeeded', parser.codes.fetch('libx264:x264')
  end

  it 'detects failures' do
    assert_predicate parser, :failed?
    refute_predicate ::PackmanNova::Pbuild::ResultParser.parse("succeeded: 1\n    fdk-aac\n"), :failed?
  end

  it 'accepts non-terse lines with details and empty input' do
    parser = ::PackmanNova::Pbuild::ResultParser.parse("unresolvable: 1\n    ffmpeg-6 (nothing provides foo)\n")

    assert_equal({ 'ffmpeg-6' => 'unresolvable' }, parser.codes)
    assert_equal({ 'ffmpeg-6' => 'nothing provides foo' }, parser.details)
    assert_empty ::PackmanNova::Pbuild::ResultParser.parse('').codes
  end
end
