# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Site::Model, :site do
  let(:state) { site_state }
  let(:states) { { 'opensuse_tumbleweed' => state, 'opensuse_leap_16.0' => nil, 'opensuse_leap_16.1' => state.merge('key' => nil) } }
  let(:model) { ::PackmanNova::Site::Model.new(config: site_config, states:) }

  it 'lists every configured distro in order' do
    assert_equal %w[opensuse_tumbleweed opensuse_leap_16.0 opensuse_leap_16.1], model.distros.map(&:id)
    assert_equal [true, false, true], model.distros.map(&:published?)
  end

  it 'derives the key URL from the public URL' do
    assert_equal 'https://packman.example.org/packman-nova.key', model.key_url
  end

  it 'formats the key in groups of four' do
    assert_equal({ 'id' => 'C6D7 E8F9 3F1C 2A9B', 'fingerprint' => '0A1B 2C3D 4E5F 6071 8293 A4B5 C6D7 E8F9 3F1C 2A9B' }, model.key)
  end

  it 'takes the key from another distro when its own state has none' do
    model = ::PackmanNova::Site::Model.new(config: site_config, states: states.merge('opensuse_tumbleweed' => nil, 'opensuse_leap_16.1' => state))

    assert_equal 'C6D7 E8F9 3F1C 2A9B', model.key.fetch('id')
  end

  it 'has no key when no state has one' do
    assert_nil ::PackmanNova::Site::Model.new(config: site_config, states: { 'opensuse_tumbleweed' => state.except('key') }).key
  end

  it 'reports the newest generation time' do
    newer = state.merge('generated_at' => '2026-10-01T10:00:00Z')
    model = ::PackmanNova::Site::Model.new(config: site_config, states: states.merge('opensuse_leap_16.0' => newer))

    assert_equal '2026-10-01 10:00 UTC', model.to_h.fetch('generated_at')
  end

  it 'exposes every template variable' do
    assert_equal %w[description distros generated_at generated_at_iso key key_url pipeline_api_url public_url source_url title], model.to_h.keys.sort
    assert_equal 'https://github.com/olegantonyan/packman-nova', model.to_h.fetch('source_url')
    assert_equal 'https://api.github.com/repos/olegantonyan/packman-nova/actions/workflows/build-publish.yml/runs?per_page=1', model.pipeline_api_url
  end

  it 'takes the source URL from site.source_url' do
    with_tmpdir do |dir|
      path = ::File.join(dir, 'packman-nova.yml')
      ::File.write(path, "site:\n  source_url: https://github.com/example/packman-nova\n")
      config = load_config(env: ::SiteSpec::PUBLIC_ENV, path:)

      assert_equal 'https://github.com/example/packman-nova', ::PackmanNova::Site::Model.new(config:, states:).source_url
    end
  end

  it 'has no pipeline status for a non-GitHub source URL' do
    with_tmpdir do |dir|
      path = ::File.join(dir, 'packman-nova.yml')
      ::File.write(path, "site:\n  source_url: https://gitlab.com/example/packman-nova\n")
      config = load_config(env: ::SiteSpec::PUBLIC_ENV, path:)

      assert_nil ::PackmanNova::Site::Model.new(config:, states:).pipeline_api_url
    end
  end
end
