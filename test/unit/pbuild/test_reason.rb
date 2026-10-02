# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Pbuild::Reason do
  it 'reads the explanation' do
    assert_equal 'new build', ::PackmanNova::Pbuild::Reason.parse("<reason>\n  <explain>new build</explain>\n  <time>1759140000</time>\n</reason>\n")
  end

  it 'adds the old source md5' do
    xml = '<reason><explain>source change</explain><time>1</time><oldsource>0123456789abcdef0123456789abcdef</oldsource></reason>'

    assert_equal 'source change: old source 01234567', ::PackmanNova::Pbuild::Reason.parse(xml)
  end

  it 'lists package changes' do
    xml = '<reason><explain>meta change</explain><packagechange change="md5sum" key="libx264-devel"/><packagechange change="added" key="nasm"/></reason>'

    assert_equal 'meta change: libx264-devel (md5sum), nasm (added)', ::PackmanNova::Pbuild::Reason.parse(xml)
  end

  it 'returns nil for missing or broken files' do
    with_tmpdir do |dir|
      path = ::File.join(dir, '_reason')

      assert_nil ::PackmanNova::Pbuild::Reason.read(path)
      ::File.write(path, '<reason><explain>')

      assert_nil ::PackmanNova::Pbuild::Reason.read(path)
    end
  end
end

describe ::PackmanNova::Pbuild::JobHistory do
  it 'keeps the last job per package with its duration' do
    xml = <<~XML
      <jobhistlist>
        <jobhist package="fdk-aac" srcmd5="a" readytime="100" starttime="110" endtime="150" code="failed" reason="new build"/>
        <jobhist package="fdk-aac" srcmd5="b" readytime="200" starttime="210" endtime="290" code="succeeded" reason="source change"/>
        <jobhist package="libx264:x264" starttime="300" endtime="301" code="succeeded"/>
      </jobhistlist>
    XML
    history = ::PackmanNova::Pbuild::JobHistory.parse(xml)

    assert_equal %w[fdk-aac libx264:x264], history.keys
    assert_equal({ code: 'succeeded', starttime: ::Time.at(210).utc, endtime: ::Time.at(290).utc, duration_sec: 80, reason: 'source change' }, history['fdk-aac'])
  end

  it 'returns an empty hash for missing or broken files' do
    with_tmpdir do |dir|
      path = ::File.join(dir, '_jobhistory')

      assert_empty ::PackmanNova::Pbuild::JobHistory.read(path)
      ::File.write(path, '<jobhistlist><jobhist')

      assert_empty ::PackmanNova::Pbuild::JobHistory.read(path)
    end
  end
end
