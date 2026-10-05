# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Pbuild::ResultParser do
  let(:parser) { ::PackmanNova::Pbuild::ResultParser.parse(::File.read(fixture_path('pbuild', 'result-terse.txt'))) }

  it 'maps names to codes' do
    assert_equal({ 'fdk-aac' => 'succeeded', 'libx264:x264' => 'succeeded', 'vlc' => 'failed', 'ffmpeg-6' => 'unresolvable' }, parser.codes)
  end

  it 'accepts non-terse lines with details and empty input' do
    parser = ::PackmanNova::Pbuild::ResultParser.parse("unresolvable: 1\n    ffmpeg-6 (nothing provides foo)\n")

    assert_equal({ 'ffmpeg-6' => 'unresolvable' }, parser.codes)
    assert_equal({ 'ffmpeg-6' => 'nothing provides foo' }, parser.details)
    assert_empty ::PackmanNova::Pbuild::ResultParser.parse('').codes
  end
end
