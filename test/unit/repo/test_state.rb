# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Repo::State do
  let(:data) do
    {
      'schema' => 1, 'generated_at' => '2026-09-29T10:00:00Z', 'run' => 3, 'release' => '1699.3.nova.1', 'tumbleweed_snapshot' => '20260924',
      'key' => { 'id' => 'ABCD', 'fingerprint' => 'FFFF' },
      'files' => {
        'x86_64/a-1-1.x86_64.rpm' => { 'sha256' => 's1', 'size' => 1, 'package' => 'a' },
        'src/a-1-1.src.rpm' => { 'sha256' => 's2', 'size' => 2, 'package' => 'a' },
        'x86_64/b-1-1.x86_64.rpm' => { 'sha256' => 's3', 'size' => 3, 'package' => 'b' }
      },
      'packages' => { 'a' => { 'status' => 'succeeded' }, 'c' => { 'status' => 'failed' } }
    }
  end

  it 'round-trips through state.json' do
    with_tmpdir do |dir|
      path = ::File.join(dir, 'repo', 'state.json')
      ::PackmanNova::Repo::State.new(data).write(path)
      state = ::PackmanNova::Repo::State.load(path)

      assert_equal data, state.to_h
      assert_equal 3, state.run
      assert_equal 'ABCD', state.key_id
      assert_equal ['src/a-1-1.src.rpm', 'x86_64/a-1-1.x86_64.rpm'], state.files_of('a')
      assert_equal %w[a b c], state.package_names
    end
  end

  it 'loads an empty state when the file is missing' do
    with_tmpdir do |dir|
      state = ::PackmanNova::Repo::State.load(::File.join(dir, 'state.json'))

      assert_predicate state, :empty?
      assert_nil state.run
      assert_empty state.files
    end
  end

  it 'rejects files missing required keys' do
    with_tmpdir do |dir|
      path = ::File.join(dir, 'state.json')
      ::File.write(path, '{"schema":1}')

      assert_raises(::PackmanNova::Error) { ::PackmanNova::Repo::State.load(path) }
      assert_raises(::PackmanNova::Error) { ::PackmanNova::Repo::State.new({ 'schema' => 1 }).write(path) }
    end
  end

  it 'compares content without generation time' do
    later = ::PackmanNova::Repo::State.new(data.merge('generated_at' => '2026-10-01T00:00:00Z'))

    assert ::PackmanNova::Repo::State.new(data).same_content?(later)
    refute ::PackmanNova::Repo::State.new(data).same_content?(::PackmanNova::Repo::State.new(data.merge('run' => 4)))
  end
end
