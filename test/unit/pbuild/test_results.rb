# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Pbuild::Results do
  let(:dir) { fixture_path('pbuild', '_build.tumbleweed.x86_64') }
  let(:results) { ::PackmanNova::Pbuild::Results.scan(dir) }

  it 'lists package dirs, skipping .pbuild and _jobhistory' do
    assert_equal %w[fdk-aac libx264:x264 wp2-fails], results.keys
  end

  it 'splits rpms of a succeeded package' do
    fdk = results.fetch('fdk-aac')

    assert_equal 'succeeded', fdk.status
    assert_equal %w[fdk-aac-devel-2.0.3-1699.2.nova.1.x86_64.rpm libfdk-aac2-2.0.3-1699.2.nova.1.x86_64.rpm], fdk.binary_rpms
    assert_equal %w[fdk-aac-debugsource-2.0.3-1699.2.nova.1.x86_64.rpm libfdk-aac2-debuginfo-2.0.3-1699.2.nova.1.x86_64.rpm], fdk.debuginfo_rpms
    assert_equal 'fdk-aac-2.0.3-1699.2.nova.1.src.rpm', fdk.srpm
    assert_empty fdk.noarch_rpms
    assert_equal ::File.join(dir, 'fdk-aac', '_log'), fdk.log
    assert_equal 'forced rebuild', fdk.reason
  end

  it 'takes time and duration from the newest job history entry' do
    fdk = results.fetch('fdk-aac')

    assert_equal ::Time.at(1_790_666_744).utc, fdk.built_at
    assert_equal 69, fdk.duration_sec
    assert fdk.built_since?(::Time.at(1_790_666_675.5))
    refute fdk.built_since?(::Time.at(1_790_666_745))
  end

  it 'reports a failed rebuild even if an old success marker remains' do
    failed = results.fetch('wp2-fails')

    assert_equal 'failed', failed.status
    assert_empty failed.rpm_files
    assert_nil failed.srpm
    assert_equal 'source change: old source 01234567', failed.reason
    assert_equal 35, failed.duration_sec
  end

  it 'handles multibuild flavors and stale success markers' do
    x264 = results.fetch('libx264:x264')

    assert_equal %w[libx264 x264], [x264.name, x264.flavor]
    assert_equal 'unknown', x264.status
    assert_equal ['x264-0.165.3222-1699.3.nova.1.x86_64.rpm'], x264.binary_rpms
    assert_nil x264.log
    assert_nil x264.duration_sec
    assert_equal ::File.mtime(::File.join(dir, 'libx264:x264', '_meta')).utc, x264.built_at
  end

  it 'returns nothing for a missing directory' do
    assert_empty ::PackmanNova::Pbuild::Results.scan(fixture_path('pbuild', 'missing'))
  end

  it 'classifies noarch rpms' do
    result = ::PackmanNova::Pbuild::PackageResult.new(key: 'k', dir: '/d', rpm_files: %w[k-doc-1-1699.1.nova.1.noarch.rpm k-1-1699.1.nova.1.nosrc.rpm], status: nil)

    assert_equal ['k-doc-1-1699.1.nova.1.noarch.rpm'], result.noarch_rpms
    assert_equal 'k-1-1699.1.nova.1.nosrc.rpm', result.srpm
    assert_nil result.flavor
  end
end
