# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Release do
  it 'formats the template' do
    assert_equal '1699.4.nova.1', ::PackmanNova::Release.new(template: '%{suse_version}.%{run}.nova.1', suse_version: 1699, run: 4).to_s
  end

  it 'raises ConfigError on unknown placeholders' do
    assert_raises(::PackmanNova::ConfigError) { ::PackmanNova::Release.new(template: '%{nope}.%{run}', suse_version: 1699, run: 1).to_s }
  end

  it 'parses the run from release strings and rpm file names' do
    assert_equal 3, ::PackmanNova::Release.parse_run('1699.3.nova.1')
    assert_equal 12, ::PackmanNova::Release.parse_run('libfdk-aac2-2.0.3-1699.12.nova.1.x86_64.rpm')
    assert_equal 7, ::PackmanNova::Release.parse_run('ffmpeg-8-mini-libs-1699-1699.7.nova.2.x86_64.rpm')
  end

  it 'returns nil for foreign releases' do
    assert_nil ::PackmanNova::Release.parse_run('libfdk-aac2-2.0.3-1.2.x86_64.rpm')
    assert_nil ::PackmanNova::Release.parse_run(nil)
  end

  it 'parses with a custom template' do
    assert_equal 9, ::PackmanNova::Release.parse_run('foo-1.0-9.pm.1699.noarch.rpm', template: '%{run}.pm.%{suse_version}')
    assert_nil ::PackmanNova::Release.parse_run('foo-1.0-1699.9.nova.1.noarch.rpm', template: '%{run}.pm.%{suse_version}')
  end
end
