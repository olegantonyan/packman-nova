# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Cli::Publish do
  it 'parses its options and passes them to the publisher' do
    options = {}
    parser = ::OptionParser.new { |p| ::PackmanNova::Cli::Publish.options(p, options) }
    parser.parse!(%w[--provider s3 --unsigned --dry-run --no-site --arch x86_64])

    assert_equal({ provider: 's3', unsigned: true, dry_run: true, site: false, arch: 'x86_64' }, options)
    assert_raises(::OptionParser::InvalidArgument) { parser.parse!(%w[--provider ftp]) }
  end
end
