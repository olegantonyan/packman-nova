# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sources::DownloadCache do
  let(:dir) { ::Dir.mktmpdir('packman-nova-cache-') }
  let(:workdir) { ::PackmanNova::Workdir.new(root: dir) }
  let(:cache) { ::PackmanNova::Sources::DownloadCache.new(workdir: workdir) }
  let(:content) { 'payload' }
  let(:sha256) { ::PackmanNova::Utils::Digest.sha256_string(content) }

  after { ::FileUtils.rm_rf(dir) }

  def blob_files
    ::Dir.glob(::File.join(dir, 'cache', 'blobs', '*', '{*,.*}')).map { |path| ::File.basename(path) }
  end

  it 'stores verified downloads under their sha256' do
    blob = cache.fetch(sha256: sha256, size: content.bytesize) { |tmp| ::File.write(tmp, content) }

    assert_equal workdir.cache_blob(sha256: sha256), blob.path
    assert_equal content, ::File.read(blob.path)
  end

  it 'does not call the block when the blob is cached' do
    cache.fetch(sha256: sha256, size: nil) { |tmp| ::File.write(tmp, content) }

    assert_equal sha256, cache.fetch(sha256: sha256, size: content.bytesize) { flunk }.sha256
  end

  it 'rejects checksum and size mismatches and leaves no temp file' do
    assert_raises(::PackmanNova::Sources::ChecksumMismatch) { cache.fetch(sha256: 'f' * 64, size: nil) { |tmp| ::File.write(tmp, content) } }
    assert_raises(::PackmanNova::Sources::ChecksumMismatch) { cache.fetch(sha256: sha256, size: 1) { |tmp| ::File.write(tmp, content) } }
    assert_empty blob_files
  end

  it 'computes the sha256 when none is known yet' do
    blob = cache.fetch(sha256: nil, size: nil) { |tmp| ::File.write(tmp, content) }

    assert_equal [sha256, content.bytesize], [blob.sha256, blob.size]
  end

  it 'stores OBS files by md5' do
    md5 = ::PackmanNova::Utils::Digest.md5_string(content)
    path = cache.store_md5(md5: md5, size: content.bytesize) { |tmp| ::File.write(tmp, content) }

    assert_equal workdir.cache_blob(md5: md5), path
    assert_raises(::PackmanNova::Sources::ChecksumMismatch) { cache.store_md5(md5: '0' * 32) { |tmp| ::File.write(tmp, content) } }
  end
end
