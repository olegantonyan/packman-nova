# frozen_string_literal: true

require 'test_helper'

describe 'CLI commands' do
  let(:root) { ::Dir.mktmpdir('packman-nova-cli-test-') }
  let(:config) { load_config(env: { 'PACKMAN_NOVA_WORKDIR' => root, 'PACKMAN_NOVA_REPO_PATH' => nil }) }
  let(:out) { ::StringIO.new }

  after { ::FileUtils.rm_rf(root) }

  def write_json(relative, data)
    path = ::File.join(root, relative)
    ::FileUtils.mkdir_p(::File.dirname(path))
    ::File.write(path, ::JSON.generate(data))
  end

  def run_cli(*argv)
    code = with_env('PACKMAN_NOVA_WORKDIR' => nil) { ::PackmanNova::Cli.new(argv: ['-w', root, '--no-log-file', *argv], out:, err: out).call }
    [code, out.string]
  end

  def command(klass, **options)
    klass.new(config:, logger: null_logger, options:, out:)
  end

  describe ::PackmanNova::Cli::Status do
    before do
      write_json('state/sync.json', { 'schema' => 1, 'packages' => { 'fdk-aac' => { 'kind' => 'native', 'srcmd5' => '0123456789abcdef' }, 'libx264' => { 'kind' => 'native' } } })
      write_json('state/last-build.json', {
                   'schema' => 1, 'run' => 2, 'release' => '1699.2.nova.1', 'started_at' => 's', 'finished_at' => '2026-09-29T12:00:00Z',
                   'packages' => {
                     'fdk-aac' => { 'code' => 'succeeded', 'rpms' => %w[libfdk-aac2-2.0.3-1699.2.nova.1.x86_64.rpm fdk-aac-devel-2.0.3-1699.2.nova.1.x86_64.rpm],
                                    'srpm' => 'fdk-aac-2.0.3-1699.2.nova.1.src.rpm', 'built_at' => '2026-09-29T11:59:00Z' },
                     'libx264:x264' => { 'code' => 'failed', 'rpms' => [], 'srpm' => nil }
                   }
                 })
      write_json('repo/opensuse_tumbleweed/essentials/state.json', { 'run' => 1, 'packages' => { 'fdk-aac' => { 'release' => '1699.1.nova.1' } } })
    end

    it 'prints a table joining sync, build and repo state' do
      code, text = run_cli('status')

      assert_equal 0, code
      assert_includes text, 'last build: run 2, release 1699.2.nova.1'
      assert_match(/^fdk-aac +native +01234567 +succeeded +1699\.2\.nova\.1 +2 +2026-09-29T11:59:00Z +1699\.1\.nova\.1$/, text)
      assert_match(/^libx264 +native +- +- +- +0 +- +-$/, text)
      assert_match(/^libx264:x264 +native +- +failed +- +0 +- +-$/, text)
    end

    it 'prints JSON' do
      code, text = run_cli('status', '--json')
      data = ::JSON.parse(text)

      assert_equal 0, code
      assert_equal 2, data['run']
      assert_equal({ 'package' => 'fdk-aac', 'kind' => 'native', 'srcmd5' => '01234567', 'code' => 'succeeded', 'release' => '1699.2.nova.1',
                     'rpms' => 2, 'built_at' => '2026-09-29T11:59:00Z', 'published' => '1699.1.nova.1' }, data['packages'].first)
    end
  end

  it 'reports an empty workdir' do
    code, text = run_cli('status')

    assert_equal 0, code
    assert_equal "no build recorded yet\n", text
  end

  describe ::PackmanNova::Cli::Clean do
    before do
      ::FileUtils.mkdir_p(::File.join(root, 'project', '_build.tumbleweed.x86_64', 'fdk-aac'))
      ::FileUtils.mkdir_p(::File.join(root, 'project', 'fdk-aac'))
      ::FileUtils.mkdir_p(::File.join(root, 'cache', 'blobs'))
    end

    it 'removes results with --yes' do
      assert_equal 0, command(::PackmanNova::Cli::Clean, results: true, yes: true).call

      refute_path_exists ::File.join(root, 'project', '_build.tumbleweed.x86_64')
      assert_path_exists ::File.join(root, 'project', 'fdk-aac')
      assert_path_exists ::File.join(root, 'cache')
    end

    it 'asks before removing' do
      clean = ::PackmanNova::Cli::Clean.new(config:, logger: null_logger, options: { cache: true }, out:, input: ::StringIO.new("n\n"))

      assert_equal 0, clean.call
      assert_path_exists ::File.join(root, 'cache')
      assert_includes out.string, "remove #{root}/cache? [y/N]"

      ::PackmanNova::Cli::Clean.new(config:, logger: null_logger, options: { cache: true }, out:, input: ::StringIO.new("y\n")).call

      refute_path_exists ::File.join(root, 'cache')
    end

    it 'requires a target' do
      assert_raises(::OptionParser::MissingArgument) { command(::PackmanNova::Cli::Clean).call }
    end
  end

  it 'rejects unknown image subcommands' do
    code, text = run_cli('image', 'frobnicate')

    assert_equal 1, code
    assert_includes text, "unknown subcommand 'frobnicate'"
  end

  it 'prints the dry-run command from the build CLI' do
    code, text = run_cli('build', '--dry-run', '--single', 'fdk-aac', '--no-repo-refresh', '--buildjobs', '4')

    assert_equal 0, code
    assert_match(%r{ pbuild .* --buildjobs 4 --jobs 8 --release 1699\.1\.nova\.1 --no-repo-refresh --single fdk-aac /project$}, text)
  end
end
