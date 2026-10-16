# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Site::DistroModel, :site do
  let(:state) { site_state }
  let(:model) { ::PackmanNova::Site::DistroModel.new(config: site_config, state:) }
  let(:rows) { model.packages.to_h { |row| [row.fetch('name'), row] } }

  it 'derives URLs from the public URL' do
    assert_equal 'https://packman.example.org', model.public_url
    assert_equal 'https://packman.example.org/opensuse_tumbleweed/essentials', model.repo_url
    assert_equal 'https://packman.example.org/opensuse_tumbleweed/essentials/packman-nova.repo', model.repo_file_url
  end

  it 'falls back to a file URL of the localfs path' do
    config = site_config('PACKMAN_NOVA_PUBLIC_URL' => nil, 'PACKMAN_NOVA_REPO_PATH' => '/srv/nova')

    assert_equal 'file:///srv/nova/opensuse_tumbleweed/essentials', ::PackmanNova::Site::DistroModel.new(config:, state:).repo_url
  end

  it 'falls back to the workdir repo dir when no localfs path is set' do
    config = site_config('PACKMAN_NOVA_PUBLIC_URL' => nil)

    assert_equal 'file:///w/repo', ::PackmanNova::Site::DistroModel.new(config:, state:).public_url
  end

  it 'builds the install commands' do
    assert_equal([
                   'sudo zypper ar -f -p 80 https://packman.example.org/opensuse_tumbleweed/essentials/packman-nova.repo',
                   'sudo zypper --gpg-auto-import-keys ref',
                   'sudo zypper dup --from packman-nova-essentials --allow-vendor-change'
                 ], model.commands.map { |command| command.fetch('text') })
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

    assert_equal 'opensuse_tumbleweed-pkg-libx264-x264', row.fetch('anchor')
    assert_equal(%w[x264-0.165.3222-1699.7.nova.1.x86_64.rpm libx264-0.165.3222-1699.7.nova.1.src.rpm], row.fetch('files').map { |file| file.fetch('name') })
  end

  it 'matches files by the package rpm list when the file owner differs' do
    state['files'].each_value { |meta| meta['package'] = 'libx264' if meta['package'] == 'libx264:x264' }

    assert_equal 2, rows.fetch('libx264:x264').fetch('files').size
  end

  it 'computes totals' do
    assert_equal({ 'packages' => 3, 'succeeded' => 2, 'not_succeeded' => 1, 'binary_rpms' => 5, 'source_rpms' => 3, 'size' => '53.7 MiB' }, model.totals)
  end

  it 'uses the distro of its config for repo paths and command ids' do
    leap = ::PackmanNova::Site::DistroModel.new(config: site_config.for_distro('opensuse_leap_16.0'), state:)

    assert_equal 'https://packman.example.org/opensuse_leap_16.0/essentials', leap.repo_url
    assert_equal 'opensuse_leap_16.0-cmd-add', leap.commands.first.fetch('id')
    assert_equal 'openSUSE Leap 16.0', leap.to_h.fetch('name')
  end

  it 'is unpublished without a state' do
    empty = ::PackmanNova::Site::DistroModel.new(config: site_config, state: nil)

    refute_predicate empty, :published?
    assert_empty empty.packages
  end

  it 'exposes every template variable' do
    assert_equal %w[baseurls commands distro_snapshot generated_at generated_at_iso id name packages packages_url published release repo_file_url repo_url run slug totals],
                 model.to_h.keys.sort
    assert_equal '2026-09-29 08:15 UTC', model.to_h.fetch('generated_at')
    assert_equal 'https://packman.example.org/opensuse_tumbleweed/essentials/packages.json', model.to_h.fetch('packages_url')
  end
end
