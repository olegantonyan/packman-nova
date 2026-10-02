# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sources::Listing do
  let(:listing) { ::PackmanNova::Sources::Listing.parse(::File.read(fixture_path('sync', 'obs_directory.xml')), label: 'demo') }

  it 'parses srcmd5 and entries sorted by name' do
    assert_equal 'fac92e8502a9b282a0616cfba699d9d2', listing.srcmd5
    assert_equal %w[_multibuild demo-1.0.tar.gz demo.changes demo.spec], listing.names
  end

  it 'exposes md5 and size per entry' do
    entry = listing.entry('demo-1.0.tar.gz')

    assert_equal ['034956cbb1e3629e7cade3d311ffd06a', 5_004_148], [entry.md5, entry.size]
    assert_nil listing.entry('nope')
  end

  it 'raises SyncError with the OBS status summary' do
    error = assert_raises(::PackmanNova::SyncError) do
      ::PackmanNova::Sources::Listing.parse(::File.read(fixture_path('sync', 'obs_not_found.xml')), label: 'openSUSE:Factory/nope')
    end

    assert_equal 'openSUSE:Factory/nope: Package not found: openSUSE:Factory/nope', error.message
  end
end
