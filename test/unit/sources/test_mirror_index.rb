# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sources::MirrorIndex do
  let(:index) { ::PackmanNova::Sources::MirrorIndex.parse(::File.read(fixture_path('sync', 'mirror_index.html')), base_url: 'https://m.example/src') }

  def newest(package)
    ::PackmanNova::Sources::MirrorIndex.newest(index.candidates(package))
  end

  it 'lists only src.rpm links' do
    assert_equal 6, index.file_names.size
    refute_includes index.file_names, 'x265-4.1-1699.1.pm.10.x86_64.rpm'
  end

  it 'picks the newest version-release of exactly the named package' do
    assert_equal 'ffmpeg-6-6.1.10-1699.1.pm.2.src.rpm', newest('ffmpeg-6').file_name
    assert_equal 'https://m.example/src/SVT-AV1-3.0.1-1699.1.pm.5.src.rpm', newest('SVT-AV1').url
    assert_equal '0.0.6', newest('libfprint-2-tod1-goodix').version
  end

  it 'returns nil when nothing matches' do
    assert_nil newest('ffmpeg')
  end
end
