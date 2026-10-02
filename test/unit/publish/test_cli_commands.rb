# frozen_string_literal: true

require 'test_helper'
require_relative 'fakes'

describe ::PackmanNova::Cli::Gpg do
  let(:out) { ::StringIO.new }
  let(:log) { ::StringIO.new }
  let(:encoded) { ::PackmanNova::Gpg.to_base64(PublishFakes::PRIVATE_ARMOR) }

  def run_gpg(*args, env: {}, config_path: nil, input: ::StringIO.new, **options)
    config = load_config(env: { 'GPG_PRIVATE_KEY_BASE64' => encoded }.merge(env), path: config_path)
    logger = ::PackmanNova::Logging::Logger.new(outputs: [log], filters: config.secrets)
    ::PackmanNova::Cli::Gpg.new(config: config, logger: logger, options: options, args: args, out: out, gpg: gpg, input: input).call
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

  it 'shows info for the configured key and whether the public key file matches' do
    with_tmpdir do |dir|
      public_key = ::File.join(dir, 'k.key')
      ::File.write(public_key, PublishFakes::PUBLIC_ARMOR)
      user = ::File.join(dir, 'u.yml')
      ::File.write(user, "signing:\n  public_key_file: #{public_key}\n")
      run_gpg('info', config_path: user)
    end

    assert_includes out.string, "type:        private\n"
    assert_includes out.string, "fingerprint: #{PublishFakes::FINGERPRINT}\n"
    assert_match(/public key: .* matches$/, out.string)
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

  it 'exports the public key to signing.public_key_file' do
    with_tmpdir do |dir|
      public_key = ::File.join(dir, 'keys', 'packman-nova.key')
      user = ::File.join(dir, 'u.yml')
      ::File.write(user, "signing:\n  public_key_file: #{public_key}\n")
      run_gpg('export-public', config_path: user)

      assert_equal PublishFakes::PUBLIC_ARMOR, ::File.read(public_key)
    end
    refute_includes log.string, encoded
  end

  it 'rejects unknown subcommands and a missing key' do
    assert_raises(::OptionParser::InvalidArgument) { run_gpg('frobnicate') }
    assert_raises(::PackmanNova::GpgError) { run_gpg('export-public', env: { 'GPG_PRIVATE_KEY_BASE64' => nil }) }
  end
end

describe ::PackmanNova::Cli::State do
  it 'pushes and pulls through the provider under the workdir lock' do
    with_tmpdir do |dir|
      ::FileUtils.mkdir_p(::File.join(dir, 'state'))
      ::File.write(::File.join(dir, 'state', 'run-counter.json'), '{"run":3}')
      store = {}
      provider = ::Object.new
      provider.define_singleton_method(:upload) { |path, key, content_type:| store[key] = [::File.binread(path), content_type] }
      provider.define_singleton_method(:download) { |key, path| ::File.binwrite(path, store.fetch(key).first) && path }
      provider.define_singleton_method(:exist?) { |key| store.key?(key) }
      config = load_config(env: { 'PACKMAN_NOVA_WORKDIR' => dir })
      command = ->(name) { ::PackmanNova::Cli::State.new(config: config, logger: null_logger, args: [name], provider: provider) }

      assert_equal 0, command.call('push').call
      ::FileUtils.rm_rf(::File.join(dir, 'state'))

      assert_equal 0, command.call('pull').call
      assert_equal '{"run":3}', ::File.read(::File.join(dir, 'state', 'run-counter.json'))
      assert_raises(::OptionParser::InvalidArgument) { command.call('sync').call }
    end
  end

  it 'requires the s3 settings' do
    with_tmpdir do |dir|
      config = load_config(env: { 'PACKMAN_NOVA_WORKDIR' => dir, 'CLOUDFLARE_R2_BUCKET' => nil })

      assert_raises(::PackmanNova::ConfigError) { ::PackmanNova::Cli::State.new(config: config, logger: null_logger, args: ['push']).call }
    end
  end
end

describe ::PackmanNova::Cli::Publish do
  it 'parses its options and passes them to the publisher' do
    options = {}
    parser = ::OptionParser.new { |p| ::PackmanNova::Cli::Publish.options(p, options) }
    parser.parse!(%w[--provider s3 --unsigned --dry-run --no-site --arch x86_64])

    assert_equal({ provider: 's3', unsigned: true, dry_run: true, site: false, arch: 'x86_64' }, options)
    assert_raises(::OptionParser::InvalidArgument) { parser.parse!(%w[--provider ftp]) }
  end
end
