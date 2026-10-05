# frozen_string_literal: true

require 'test_helper'

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
      command = ->(name) { ::PackmanNova::Cli::State.new(config:, logger: null_logger, args: [name], bucket: provider) }

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

      assert_raises(::PackmanNova::ConfigError) { ::PackmanNova::Cli::State.new(config:, logger: null_logger, args: ['push']).call }
    end
  end
end
