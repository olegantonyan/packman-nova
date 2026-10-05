# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Config do
  let(:blank_env) do
    ::PackmanNova::Config::Loader::ENV_OVERRIDES.keys.to_h { |key| [key, nil] }
                                                .merge('GPG_PRIVATE_KEY_BASE64' => nil, 'CLOUDFLARE_R2_SECRET_ACCESS_KEY' => nil, 'CLOUDFLARE_API_TOKEN' => nil)
  end

  it 'loads committed defaults into typed nested sections' do
    config = load_config(env: blank_env)

    assert_equal 1699, config.distro.suse_version
    assert_equal 2, config.pbuild.buildjobs
    assert_equal 'https://api.opensuse.org/public', config.sources.obs_api
  end

  it 'exposes booleans, lists and deeply nested values' do
    config = load_config(env: blank_env)

    assert_predicate config.pbuild, :checks?
    assert_equal ['x86_64'], config.distro.arches
    assert_equal 'auto', config.repository.s3.region
  end

  it 'freezes the config and its sections' do
    config = load_config(env: blank_env)

    assert_predicate config, :frozen?
    assert_predicate config.repository.s3, :frozen?
  end

  it 'expands ${VAR} from the process environment' do
    config = load_config(env: blank_env.merge('PACKMAN_NOVA_WORKDIR' => '/srv/nova', 'CLOUDFLARE_R2_ENDPOINT' => 'https://r2.example'))

    assert_equal '/srv/nova', config.workdir.root
    assert_equal 'https://r2.example', config.repository.s3.endpoint
  end

  it 'expands missing variables to empty strings and records their names' do
    config = load_config(env: blank_env)

    assert_equal '', config.repository.public_url
    assert_includes config.env_vars_missing, 'PACKMAN_NOVA_PUBLIC_URL'
    assert_includes config.env_vars_used, 'GPG_PRIVATE_KEY_BASE64'
  end

  it 'expands ${VAR} inside strings and lists of a user file, leaving $VAR alone' do
    with_tmpdir do |dir|
      ::File.write(::File.join(dir, 'packman-nova.yml'), "project_name: x-${NOVA_A}-y\ndistro:\n  arches: ['${NOVA_A}', '$NOVA_A']\n")
      config = load_config(env: blank_env.merge('NOVA_A' => 'alpha'), cwd: dir)

      assert_equal 'x-alpha-y', config.project_name
      assert_equal %w[alpha $NOVA_A], config.distro.arches
    end
  end

  it 'reads variables from .env in the working directory' do
    with_tmpdir do |dir|
      ::File.write(::File.join(dir, '.env'), "PACKMAN_NOVA_PUBLIC_URL=https://from-dotenv.example\n")
      config = load_config(env: blank_env, cwd: dir)

      assert_equal 'https://from-dotenv.example', config.repository.public_url
    end
  end

  it 'prefers the process environment over .env' do
    with_tmpdir do |dir|
      ::File.write(::File.join(dir, '.env'), "PACKMAN_NOVA_PUBLIC_URL=https://from-dotenv.example\n")
      config = load_config(env: blank_env.merge('PACKMAN_NOVA_PUBLIC_URL' => 'https://from-process.example'), cwd: dir)

      assert_equal 'https://from-process.example', config.repository.public_url
    end
  end

  it 'merges a user file over the defaults' do
    config = load_config(env: blank_env, path: fixture_path('config', 'user.yml'))

    assert_equal 'custom-project', config.project_name
    assert_equal 4, config.pbuild.buildjobs
    assert_equal %w[x86_64 aarch64], config.distro.arches
  end

  it 'picks up ./packman-nova.yml from the working directory' do
    with_tmpdir do |dir|
      ::File.write(::File.join(dir, 'packman-nova.yml'), "project_name: from-cwd\n")
      config = load_config(env: blank_env, cwd: dir)

      assert_equal 'from-cwd', config.project_name
    end
  end

  it 'lets PACKMAN_NOVA_* env win over the user file' do
    with_tmpdir do |dir|
      ::File.write(::File.join(dir, 'packman-nova.yml'), "workdir: /from/file\n")
      config = load_config(env: blank_env.merge('PACKMAN_NOVA_WORKDIR' => '/from/env'), cwd: dir)

      assert_equal '/from/env', config.workdir.root
    end
  end

  it 'applies CLI overrides last' do
    config = load_config(env: blank_env.merge('PACKMAN_NOVA_WORKDIR' => '/from/env'), overrides: { workdir: '/from/cli', offline: true })

    assert_equal '/from/cli', config.workdir.root
    assert_predicate config, :offline?
  end

  it 'raises ConfigError naming the dotted key on a type mismatch' do
    error = assert_raises(::PackmanNova::ConfigError) { load_config(env: blank_env, path: fixture_path('config', 'bad_type.yml')) }

    assert_match(/pbuild\.buildjobs: expected Integer, got String/, error.message)
  end

  it 'raises ConfigError on unknown keys' do
    error = assert_raises(::PackmanNova::ConfigError) { load_config(env: blank_env, path: fixture_path('config', 'unknown_key.yml')) }

    assert_match(/pbuild\.buildjob/, error.message)
  end

  it 'raises ConfigError for a missing explicit config file' do
    assert_raises(::PackmanNova::ConfigError) { load_config(env: blank_env, path: '/nonexistent/packman-nova.yml') }
  end

  it 'raises ConfigError when the workdir is not set' do
    config = load_config(env: blank_env)

    assert_raises(::PackmanNova::ConfigError) { config.workdir }
  end

  it 'lists only non-empty secrets' do
    config = load_config(env: blank_env.merge('GPG_PRIVATE_KEY_BASE64' => 'c2VjcmV0', 'CLOUDFLARE_API_TOKEN' => 'token-1'))

    assert_equal %w[c2VjcmV0 token-1], config.secrets
  end

  it 'resolves repository-relative paths against the project root' do
    config = load_config(env: blank_env)

    assert_equal ::File.join(::PackmanNova::Config::PROJECT_ROOT, 'container', 'Containerfile'), config.resolve(config.container.containerfile)
    assert_equal '/abs/path', config.resolve('/abs/path')
  end
end
