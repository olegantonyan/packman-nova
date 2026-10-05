# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'json'
require 'open3'

describe 'packman-nova smoke' do
  before { skip 'set PACKMAN_NOVA_INTEGRATION=1 to run' unless ::ENV['PACKMAN_NOVA_INTEGRATION'] == '1' }

  let(:root) { ::Dir.mktmpdir('packman-nova-smoke-', ::ENV.fetch('PACKMAN_NOVA_SMOKE_ROOT', ::Dir.tmpdir)) }
  let(:workdir) { ::File.join(root, 'workdir') }
  let(:config_file) { ::File.join(root, 'packman-nova.yml') }
  let(:repo) { ::File.join(workdir, 'repo') }
  let(:essentials) { ::File.join(repo, 'opensuse_tumbleweed', 'essentials') }
  let(:env) { { 'PACKMAN_NOVA_WORKDIR' => workdir, 'PACKMAN_NOVA_PUBLIC_URL' => nil, 'PACKMAN_NOVA_REPO_PATH' => nil, 'GPG_PRIVATE_KEY_BASE64' => private_key } }
  let(:private_key) { @private_key }

  after do
    if ::ENV['PACKMAN_NOVA_INTEGRATION'] == '1'
      cli('clean', '--all', '--yes')
      ::FileUtils.rm_rf(root)
    end
  end

  def cli(*argv, environment: env)
    out = ::StringIO.new
    code = with_env(environment) { ::PackmanNova::Cli.new(argv: ['-c', config_file, '-w', workdir, *argv], out:, err: out).call }
    [code, out.string]
  end

  def cli!(*argv, environment: env)
    code, text = cli(*argv, environment:)

    assert_equal 0, code, "packman-nova #{argv.join(' ')}:\n#{text.lines.last(40).join}"
    text
  end

  def throwaway_key
    ::File.write(config_file, "signing:\n  require_signature: true\n")
    @private_key = cli!('--no-log-file', 'gpg', 'generate', '--name', 'packman-nova smoke', '--email', 'smoke@example.org').lines.first.strip

    assert_includes cli!('--no-log-file', 'gpg', 'export-public'), '-----BEGIN PGP PUBLIC KEY BLOCK-----'
  end

  def in_builder(script)
    config = load_config(env:, path: config_file)
    runtime = ::PackmanNova::Container::Runtime.detect(config:)
    argv = [runtime.executable, 'run', '--rm', '-v', "#{repo}:/repo:ro", '--entrypoint', '/bin/bash', config.container.image, '-euo', 'pipefail', '-c', script]
    text, status = ::Open3.capture2e(*argv)

    assert_predicate status, :success?, text
    text
  end

  it 'syncs, builds, publishes and serves fdk-aac' do
    throwaway_key
    cli!('image', 'build')
    cli!('sync', '--package', 'fdk-aac')
    cli!('build', '--single', 'fdk-aac', '--no-sync')
    cli!('publish', '--provider', 'localfs')

    %w[repomd.xml repomd.xml.asc repomd.xml.key].each { |name| assert_path_exists ::File.join(essentials, 'x86_64', 'repodata', name) }
    state = ::JSON.parse(::File.read(::File.join(essentials, 'state.json')))
    rpm = state.fetch('files').keys.find { |path| path.match?(%r{\Ax86_64/libfdk-aac2-.*\.rpm\z}) }

    refute_nil rpm, state.fetch('files').keys.inspect
    key_id = state.dig('key', 'id')

    assert_match(/key ID #{key_id[-8..].downcase}: OK/i, in_builder("rpm --import /repo/packman-nova.key && rpm -Kv /repo/opensuse_tumbleweed/essentials/#{rpm}"))
    listing = in_builder('zypper --root /tmp/r --gpg-auto-import-keys ar file:///repo/opensuse_tumbleweed/essentials/x86_64 nova && ' \
                         'zypper --root /tmp/r --gpg-auto-import-keys ref && zypper --root /tmp/r se -s -r nova fdk-aac')

    assert_includes listing, 'libfdk-aac2'

    before = ::File.read(::File.join(essentials, 'state.json'))
    output = cli!('publish', '--provider', 'localfs')

    assert_includes output, 'repository files are up to date'
    assert_equal before, ::File.read(::File.join(essentials, 'state.json'))
  end
end
