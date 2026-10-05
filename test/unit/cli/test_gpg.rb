# frozen_string_literal: true

require 'test_helper'
require 'support/publish_fakes'

describe ::PackmanNova::Cli::Gpg do
  let(:out) { ::StringIO.new }
  let(:log) { ::StringIO.new }
  let(:encoded) { ::PackmanNova::Gpg.to_base64(PublishFakes::PRIVATE_ARMOR) }

  def run_gpg(*args, env: {}, config_path: nil, input: ::StringIO.new, **options)
    config = load_config(env: { 'GPG_PRIVATE_KEY_BASE64' => encoded }.merge(env), path: config_path)
    logger = ::PackmanNova::Logging::Logger.new(outputs: [log], filters: config.secrets)
    ::PackmanNova::Cli::Gpg.new(config:, logger:, options:, args:, out:, gpg:, input:).call
  end

  let(:gpg) do
    fake = PublishFakes::Gpg.new
    fake.define_singleton_method(:generate) { |name:, email:| PublishFakes.key.with(key_id: "#{name}|#{email}"[0, 16]) }
    fake.define_singleton_method(:public_key_from_private) { |_armor| PublishFakes::PUBLIC_ARMOR }
    fake
  end

  it 'prints only the base64 private key on stdout when generating' do
    assert_equal 0, run_gpg('generate', name: 'N', email: 'e@example.invalid')
    assert_equal "#{encoded}\n", out.string
    assert_includes log.string, 'GPG_PRIVATE_KEY_BASE64'
  end

  it 'prints armor on request and requires an email' do
    run_gpg('generate', email: 'e@example.invalid', format: 'armor')

    assert_equal PublishFakes::PRIVATE_ARMOR, out.string
    assert_raises(::OptionParser::MissingArgument) { run_gpg('generate') }
  end

  it 'shows info for the configured key' do
    run_gpg('info')

    assert_includes out.string, "type:        private\n"
    assert_includes out.string, "fingerprint: #{PublishFakes::FINGERPRINT}\n"
  end

  it 'converts between armor and base64 from a file or stdin' do
    with_tmpdir do |dir|
      file = ::File.join(dir, 'key.asc')
      ::File.write(file, PublishFakes::PUBLIC_ARMOR)
      run_gpg('convert', file, to: 'base64')
      run_gpg('convert', '-', input: ::StringIO.new(::PackmanNova::Gpg.to_base64(PublishFakes::PUBLIC_ARMOR)))
    end

    assert_equal "#{::PackmanNova::Gpg.to_base64(PublishFakes::PUBLIC_ARMOR)}\n#{PublishFakes::PUBLIC_ARMOR}", out.string
    assert_raises(::PackmanNova::GpgError) { run_gpg('convert', '-', from: 'armor', input: ::StringIO.new(encoded)) }
  end

  it 'prints the public key derived from the private key' do
    run_gpg('export-public')

    assert_equal PublishFakes::PUBLIC_ARMOR, out.string
    refute_includes log.string, encoded
  end

  it 'rejects unknown subcommands and a missing key' do
    assert_raises(::OptionParser::InvalidArgument) { run_gpg('frobnicate') }
    assert_raises(::PackmanNova::GpgError) { run_gpg('export-public', env: { 'GPG_PRIVATE_KEY_BASE64' => nil }) }
  end
end
