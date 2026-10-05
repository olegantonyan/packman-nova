# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Site::Generator, :site do
  let(:state) { site_state }
  let(:generator) { ::PackmanNova::Site::Generator.new(config: site_config, state:, logger: null_logger) }
  let(:html) { generator.render_index }

  it 'renders the install commands' do
    assert_includes html, 'sudo zypper ar -f -p 80 https://packman.example.org/opensuse_tumbleweed/essentials/packman-nova.repo'
    assert_includes html, 'sudo zypper --gpg-auto-import-keys ref'
    assert_includes html, 'sudo zypper dup --from packman-nova-essentials --allow-vendor-change'
  end

  it 'renders the key and repository facts' do
    assert_includes html, '0A1B 2C3D 4E5F 6071 8293 A4B5 C6D7 E8F9 3F1C 2A9B'
    assert_includes html, 'C6D7 E8F9 3F1C 2A9B'
    assert_includes html, 'https://packman.example.org/packman-nova.key'
    assert_includes html, '20260927'
    assert_includes html, '<title>packman-nova Essentials for openSUSE Tumbleweed</title>'
    assert_includes html, '<a href="https://github.com/olegantonyan/packman-nova">GitHub</a>'
    assert_includes html, 'data-api="https://api.github.com/repos/olegantonyan/packman-nova/actions/workflows/build-publish.yml/runs?per_page=1"'
    assert_includes html, 'Inspired by <a href="https://omnipackage.org">omnipackage.org</a>.'
  end

  it 'renders every package with its version' do
    state.fetch('packages').each do |name, entry|
      assert_includes html, ">#{name}</a>"
      assert_includes html, "#{entry.fetch('version')}-#{entry.fetch('release')}"
    end
    assert_includes html, 'https://build.opensuse.org/package/show/openSUSE:Factory/vlc'
  end

  it 'escapes state values' do
    assert_includes html, 'meta change: ffmpeg-8-libavcodec-devel &lt;8.1.3&gt;'
    refute_includes html, '<8.1.3>'
  end

  it 'escapes hostile state in text, attributes and urls' do
    payload = %("'><script>alert(1)</script><%= 7 * 7 %>)
    hostile = state.merge('run' => payload, 'generated_at' => payload, 'key' => { 'id' => payload, 'fingerprint' => payload })
    hostile['packages'] = state.fetch('packages').merge(payload => { 'status' => payload, 'reason' => payload, 'version' => payload, 'built_at' => payload })
    hostile['files'] = state.fetch('files').merge("x86_64/#{payload}.rpm" => { 'package' => payload, 'size' => payload })
    html = ::PackmanNova::Site::Generator.new(config: site_config, state: hostile, logger: null_logger).render_index

    refute_includes html, '<script>alert'
    refute_includes html, %("'>)
    assert_includes html, '&quot;&#39;&gt;&lt;script&gt;alert(1)&lt;/script&gt;&lt;%= 7 * 7 %&gt;'
  end

  it 'is self-contained' do
    assert_includes html, 'light-dark('
    assert_includes html, 'id="theme-toggle"'
    refute_match(/<link |<script src/, html)
    refute_match(/<!--/, html)
  end

  it 'renders without a key' do
    html = ::PackmanNova::Site::Generator.new(config: site_config, state: state.except('key'), logger: null_logger).render_index

    assert_includes html, 'No signing key recorded'
  end

  it 'writes index.html and packages.json' do
    with_tmpdir do |dir|
      paths = generator.write(dir)

      assert_equal [::File.join(dir, 'index.html'), ::File.join(dir, 'packages.json')], paths
      assert_equal html, ::File.read(paths.first)
      assert_equal({ 'generated_at' => state.fetch('generated_at'), 'packages' => state.fetch('packages') }, ::JSON.parse(::File.read(paths.last)))
    end
  end
end
