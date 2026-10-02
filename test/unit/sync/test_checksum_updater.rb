# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sync::ChecksumUpdater do
  let(:dir) { ::Dir.mktmpdir('packman-nova-checksums-') }
  let(:path) { ::File.join(dir, 'package.yml') }
  let(:updater) { ::PackmanNova::Sync::ChecksumUpdater.new(manifest_path: path) }

  before do
    ::File.write(path, <<~YAML)
      name: demo
      kind: native
      sources:
        - file: a.tar.gz
          urls: [https://example.org/a.tar.gz]
        - file: b.tar.gz
          urls: [https://example.org/b.tar.gz]
          sha256: #{'b' * 64}
          size: 2
      notes: keep me last
    YAML
  end

  after { ::FileUtils.rm_rf(dir) }

  it 'fills missing sha256 and size and keeps the key order' do
    assert updater.call('a.tar.gz' => { sha256: 'a' * 64, size: 1 })

    data = ::PackmanNova::Utils::Yaml.load_file(path)

    assert_equal %w[name kind sources notes], data.keys
    assert_equal({ 'file' => 'a.tar.gz', 'urls' => ['https://example.org/a.tar.gz'], 'sha256' => 'a' * 64, 'size' => 1 }, data['sources'].first)
  end

  it 'never overwrites existing checksums' do
    refute updater.call('b.tar.gz' => { sha256: 'c' * 64, size: 9 })
    assert_equal 'b' * 64, ::PackmanNova::Utils::Yaml.load_file(path)['sources'].last['sha256']
  end
end
