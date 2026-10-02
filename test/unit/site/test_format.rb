# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Site::Format do
  it 'groups hex strings by four' do
    assert_equal '0A1B 2C3D 4E5F', ::PackmanNova::Site::Format.hex_groups('0a1b2c3d4e5f')
    assert_equal 'C6D7 E8F9', ::PackmanNova::Site::Format.hex_groups('C6D7 E8F9')
    assert_nil ::PackmanNova::Site::Format.hex_groups(nil)
  end

  it 'formats ISO times in UTC and passes unparsable values through' do
    assert_equal '2026-09-29 06:15 UTC', ::PackmanNova::Site::Format.time('2026-09-29T08:15:42+02:00')
    assert_equal 'yesterday', ::PackmanNova::Site::Format.time('yesterday')
    assert_nil ::PackmanNova::Site::Format.time(nil)
  end

  it 'formats sizes with binary units' do
    assert_equal '0 B', ::PackmanNova::Site::Format.size(nil)
    assert_equal '1023 B', ::PackmanNova::Site::Format.size(1023)
    assert_equal '2.2 MiB', ::PackmanNova::Site::Format.size(2_310_144)
  end

  it 'builds HTML-safe anchors' do
    assert_equal 'pkg-libx264-x264', ::PackmanNova::Site::Format.anchor('libx264:x264')
  end
end
