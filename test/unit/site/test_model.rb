# frozen_string_literal: true

require 'test_helper'
require_relative 'site_test_support'

describe ::PackmanNova::Site::Model do
  include ::SiteTestSupport

  let(:state) { site_state }
  let(:model) { ::PackmanNova::Site::Model.new(config: site_config, state: state) }
  let(:rows) { model.packages.to_h { |row| [row.fetch('name'), row] } }

  it 'derives URLs from the public URL' do
    assert_equal 'https://packman.example.org', model.public_url
    assert_equal 'https://packman.example.org/opensuse_tumbleweed/essentials', model.repo_url
    assert_equal 'https://packman.example.org/opensuse_tumbleweed/essentials/packman-nova.repo', model.repo_file_url
    assert_equal 'https://packman.example.org/packman-nova.key', model.key_url
  end

  it 'falls back to a file URL of the localfs path' do
    config = site_config('PACKMAN_NOVA_PUBLIC_URL' => nil, 'PACKMAN_NOVA_REPO_PATH' => '/srv/nova')

    assert_equal 'file:///srv/nova/opensuse_tumbleweed/essentials', ::PackmanNova::Site::Model.new(config: config, state: state).repo_url
  end

  it 'falls back to the workdir repo dir when no localfs path is set' do
    config = site_config('PACKMAN_NOVA_PUBLIC_URL' => nil)

    assert_equal 'file:///w/repo', ::PackmanNova::Site::Model.new(config: config, state: state).public_url
  end

  it 'builds the install commands' do
    assert_equal([
                   'sudo zypper ar -f -p 80 https://packman.example.org/opensuse_tumbleweed/essentials/packman-nova.repo',
                   'sudo zypper --gpg-auto-import-keys ref',
                   'sudo zypper dup --from packman-nova-essentials --allow-vendor-change'
                 ], model.commands.map { |command| command.fetch('text') })
  end

  it 'formats the key in groups of four' do
    assert_equal({ 'id' => 'C6D7 E8F9 3F1C 2A9B', 'fingerprint' => '0A1B 2C3D 4E5F 6071 8293 A4B5 C6D7 E8F9 3F1C 2A9B' }, model.key)
  end

  it 'has no key when the state has none' do
    assert_nil ::PackmanNova::Site::Model.new(config: site_config, state: state.except('key')).key
  end

  it 'lists base URLs per arch plus sources' do
    assert_equal(%w[x86_64 src], model.baseurls.map { |baseurl| baseurl.fetch('arch') })
    assert_equal 'https://packman.example.org/opensuse_tumbleweed/essentials/src', model.baseurls.last.fetch('url')
  end

  it 'sorts package rows by name' do
    assert_equal(%w[ffmpeg-8 libx264:x264 vlc], model.packages.map { |row| row.fetch('name') })
  end

  it 'links obs-link origins to build.opensuse.org and native ones to their published src.rpm' do
    assert_equal 'https://build.opensuse.org/package/show/openSUSE:Factory/ffmpeg-8', rows.fetch('ffmpeg-8').fetch('origin_url')
    native = rows.fetch('libx264:x264')

    assert_equal 'src.rpm', native.fetch('origin_label')
    assert_equal 'https://packman.example.org/opensuse_tumbleweed/essentials/src/libx264-0.165.3222-1699.7.nova.1.src.rpm', native.fetch('origin_url')
  end

  it 'describes a succeeded package' do
    row = rows.fetch('ffmpeg-8')

    assert_equal '8.1.2-1699.7.nova.1', row.fetch('evr')
    assert_equal 'ok', row.fetch('status_class')
    assert_equal '2026-09-29 07:58 UTC', row.fetch('built_at')
    refute row.fetch('retained')
    assert_equal(%w[ffmpeg-8-8.1.2-1699.7.nova.1.x86_64.rpm libavcodec62-8.1.2-1699.7.nova.1.x86_64.rpm ffmpeg-8-8.1.2-1699.7.nova.1.src.rpm],
                 row.fetch('files').map { |file| file.fetch('name') })
  end

  it 'marks retained files of a failed package' do
    row = rows.fetch('vlc')

    assert_equal 'fail', row.fetch('status_class')
    assert row.fetch('retained')
    assert_equal 3, row.fetch('files').size
    assert_equal 'https://packman.example.org/opensuse_tumbleweed/essentials/src/vlc-3.0.21-1699.6.nova.1.src.rpm', row.fetch('files').last.fetch('url')
  end

  it 'keeps multibuild flavors as separate rows' do
    row = rows.fetch('libx264:x264')

    assert_equal 'pkg-libx264-x264', row.fetch('anchor')
    assert_equal(%w[x264-0.165.3222-1699.7.nova.1.x86_64.rpm libx264-0.165.3222-1699.7.nova.1.src.rpm], row.fetch('files').map { |file| file.fetch('name') })
  end

  it 'matches files by the package rpm list when the file owner differs' do
    state['files'].each_value { |meta| meta['package'] = 'libx264' if meta['package'] == 'libx264:x264' }

    assert_equal 2, rows.fetch('libx264:x264').fetch('files').size
  end

  it 'computes totals' do
    assert_equal({ 'packages' => 3, 'succeeded' => 2, 'not_succeeded' => 1, 'binary_rpms' => 5, 'source_rpms' => 3, 'size' => '53.7 MiB' }, model.totals)
  end

  it 'exposes every template variable' do
    assert_equal %w[baseurls commands description generated_at generated_at_iso key key_url packages pipeline_api_url public_url release repo_file_url repo_url
                    run slug source_url title totals tumbleweed_snapshot], model.to_h.keys.sort
    assert_equal '2026-09-29 08:15 UTC', model.to_h.fetch('generated_at')
    assert_equal 'https://github.com/olegantonyan/packman-nova', model.to_h.fetch('source_url')
    assert_equal 'https://api.github.com/repos/olegantonyan/packman-nova/actions/workflows/build-publish.yml/runs?per_page=1', model.pipeline_api_url
  end

  it 'takes the source URL from site.source_url' do
    with_tmpdir do |dir|
      path = ::File.join(dir, 'packman-nova.yml')
      ::File.write(path, "site:\n  source_url: https://github.com/example/packman-nova\n")
      config = load_config(env: ::SiteTestSupport::PUBLIC_ENV, path: path)

      assert_equal 'https://github.com/example/packman-nova', ::PackmanNova::Site::Model.new(config: config, state: state).source_url
    end
  end

  it 'has no pipeline status for a non-GitHub source URL' do
    with_tmpdir do |dir|
      path = ::File.join(dir, 'packman-nova.yml')
      ::File.write(path, "site:\n  source_url: https://gitlab.com/example/packman-nova\n")
      config = load_config(env: ::SiteTestSupport::PUBLIC_ENV, path: path)

      assert_nil ::PackmanNova::Site::Model.new(config: config, state: state).pipeline_api_url
    end
  end
end
