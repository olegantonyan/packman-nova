# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sources::RpmHeader do
  it 'reads the DISTURL string' do
    header = ::SrcRpmFixture.header(1000 => 'ffmpeg-8', 1123 => 'obs://build.opensuse.org/openSUSE:Factory/standard/abc-ffmpeg-8')

    assert_equal 'obs://build.opensuse.org/openSUSE:Factory/standard/abc-ffmpeg-8', ::PackmanNova::Sources::RpmHeader.new(header).disturl
  end

  it 'returns nil without a DISTURL' do
    assert_nil ::PackmanNova::Sources::RpmHeader.new(::SrcRpmFixture.header(1000 => 'demo')).disturl
  end

  it 'rejects bytes that are not an rpm header' do
    assert_raises(::PackmanNova::SyncError) { ::PackmanNova::Sources::RpmHeader.new('<html>not found</html>') }
  end
end
