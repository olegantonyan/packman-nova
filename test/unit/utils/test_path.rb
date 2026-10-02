# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Utils::Path do
  it 'writes files atomically without leaving temp files' do
    with_tmpdir do |dir|
      target = ::File.join(dir, 'nested', 'file.txt')
      ::PackmanNova::Utils::Path.atomic_write(target, 'content')

      assert_equal 'content', ::File.read(target)
      assert_equal ['file.txt'], ::Dir.children(::File.dirname(target))
    end
  end

  it 'replaces an existing directory atomically' do
    with_tmpdir do |dir|
      final = ::File.join(dir, 'pkg')
      tmp = ::File.join(dir, '.pkg.tmp')
      [final, tmp].each { |path| ::FileUtils.mkdir_p(path) }
      ::File.write(::File.join(final, 'old'), '')
      ::File.write(::File.join(tmp, 'new'), '')
      ::PackmanNova::Utils::Path.atomic_rename_dir(tmp, final)

      assert_equal ['new'], ::Dir.children(final)
      assert_equal ['pkg'], ::Dir.children(dir)
    end
  end

  it 'hardlinks files on the same filesystem' do
    with_tmpdir do |dir|
      src = ::File.join(dir, 'src')
      dst = ::File.join(dir, 'sub', 'dst')
      ::File.write(src, 'blob')
      ::PackmanNova::Utils::Path.hardlink_or_copy(src, dst)

      assert_equal ::File.stat(src).ino, ::File.stat(dst).ino
    end
  end
end

describe ::PackmanNova::Utils::JsonFile do
  it 'round-trips pretty JSON and returns the default for missing files' do
    with_tmpdir do |dir|
      path = ::File.join(dir, 'state', 'x.json')
      ::PackmanNova::Utils::JsonFile.write(path, { 'run' => 3 })

      assert_equal({ 'run' => 3 }, ::PackmanNova::Utils::JsonFile.read(path))
      assert_equal({}, ::PackmanNova::Utils::JsonFile.read(::File.join(dir, 'none.json'), default: {}))
    end
  end

  it 'raises a PackmanNova::Error on corrupted files' do
    with_tmpdir do |dir|
      path = ::File.join(dir, 'bad.json')
      ::File.write(path, '{')

      assert_raises(::PackmanNova::Error) { ::PackmanNova::Utils::JsonFile.read(path) }
    end
  end
end

describe ::PackmanNova::Utils::Digest do
  it 'hashes files and strings' do
    with_tmpdir do |dir|
      path = ::File.join(dir, 'f')
      ::File.write(path, 'abc')

      assert_equal ::PackmanNova::Utils::Digest.sha256_string('abc'), ::PackmanNova::Utils::Digest.sha256_file(path)
      assert_equal '900150983cd24fb0d6963f7d28e17f72', ::PackmanNova::Utils::Digest.md5_file(path)
    end
  end
end

describe ::PackmanNova::Utils::Xml do
  let(:document) { ::PackmanNova::Utils::Xml.parse('<directory srcmd5="abc"><entry name="a" md5="1"/><entry name="b" md5="2"/></directory>') }

  it 'reads attributes via xpath' do
    assert_equal 'abc', ::PackmanNova::Utils::Xml.attribute(document, '/directory', 'srcmd5')
    assert_equal [{ 'name' => 'a', 'md5' => '1' }, { 'name' => 'b', 'md5' => '2' }], ::PackmanNova::Utils::Xml.attributes(document, '//entry')
  end

  it 'raises a PackmanNova::Error on malformed XML' do
    assert_raises(::PackmanNova::Error) { ::PackmanNova::Utils::Xml.parse('<a><b></a>') }
  end
end

describe ::PackmanNova::Utils::Yaml do
  it 'loads with aliases and symbolized names' do
    assert_equal({ a: { x: 1 }, b: { x: 1 } }, ::PackmanNova::Utils::Yaml.load("a: &x\n  x: 1\nb: *x\n", symbolize_names: true))
  end

  it 'refuses arbitrary objects' do
    assert_raises(::Psych::DisallowedClass) { ::PackmanNova::Utils::Yaml.load('!ruby/object:Object {}') }
  end
end
