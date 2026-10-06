# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Upstream::ManifestText do
  let(:yaml) do
    <<~YAML
      name: pkg
      kind: native
      tags: [codec]
      sources:
        - file: pkg-1.0.tar.gz
          urls:
            - https://example.org/v1.0/pkg-1.0.tar.gz
          sha256: #{'a' * 64}
          size: 10
        - file: pkg-1.0.tar.gz.asc
          urls:
            - https://example.org/v1.0/pkg-1.0.tar.gz.asc
      watch:
        git: https://example.org/pkg.git
        tags: '^v(.+)$'
      notes: "keep me"
    YAML
  end
  let(:text) { ::PackmanNova::Upstream::ManifestText.new(yaml) }

  def source(file, url, sha256: nil, size: nil)
    { 'file' => file, 'urls' => [url], 'sha256' => sha256, 'size' => size }.compact
  end

  it 'rewrites one source entry in place and keeps the rest of the file' do
    updated = text.with_source(
      source('pkg-1.0.tar.gz', 'https://example.org/v1.0/pkg-1.0.tar.gz', sha256: 'a' * 64, size: 10),
      source('pkg-1.1.tar.gz', 'https://example.org/v1.1/pkg-1.1.tar.gz', sha256: 'b' * 64, size: 11)
    ).text

    assert_equal yaml.sub('pkg-1.0.tar.gz', 'pkg-1.1.tar.gz').sub('v1.0/pkg-1.0.tar.gz', 'v1.1/pkg-1.1.tar.gz')
                     .sub('a' * 64, 'b' * 64).sub('size: 10', 'size: 11'), updated
  end

  it 'appends missing checksums to the entry' do
    updated = text.with_source(
      source('pkg-1.0.tar.gz.asc', 'https://example.org/v1.0/pkg-1.0.tar.gz.asc'),
      source('pkg-1.1.tar.gz.asc', 'https://example.org/v1.1/pkg-1.1.tar.gz.asc', sha256: 'c' * 64, size: 3)
    ).text

    assert_includes updated, "      - https://example.org/v1.1/pkg-1.1.tar.gz.asc\n    sha256: #{'c' * 64}\n    size: 3\nwatch:\n"
  end

  it 'sets or replaces the watch commit' do
    once = text.with_commit('d' * 40).text
    twice = ::PackmanNova::Upstream::ManifestText.new(once).with_commit('e' * 40).text

    assert_includes once, "  tags: '^v(.+)$'\n  commit: #{'d' * 40}\nnotes:"
    assert_equal once.sub('d' * 40, 'e' * 40), twice
  end

  it 'fails for an unknown source' do
    assert_raises(::PackmanNova::UpstreamError) { text.with_source(source('nope', 'x'), source('nope', 'y')) }
  end
end
