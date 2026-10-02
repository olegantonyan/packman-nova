# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Cli do
  def run_cli(*argv, env: { 'PACKMAN_NOVA_WORKDIR' => nil })
    out = ::StringIO.new
    err = ::StringIO.new
    code = with_env(env) { ::PackmanNova::Cli.new(argv: argv, out: out, err: err).call }
    [code, out.string, err.string]
  end

  it 'prints the version' do
    assert_equal [0, "#{::PackmanNova::VERSION}\n", ''], run_cli('--version')
  end

  it 'lists every command in the help' do
    code, out, = run_cli('--help')

    assert_equal 0, code
    ::PackmanNova::Cli::COMMANDS.each_key { |name| assert_match(/^    #{name} /, out) }
  end

  it 'prints command help' do
    code, out, = run_cli('build', '--help')

    assert_equal 0, code
    assert_includes out, '--rebuild-pkg'
  end

  it 'fails on unknown commands' do
    code, _out, err = run_cli('frobnicate')

    assert_equal 1, code
    assert_includes err, "unknown command 'frobnicate'"
  end

  it 'implements every command' do
    ::PackmanNova::Cli::COMMANDS.each_value do |command_class|
      assert_equal command_class, command_class.instance_method(:call).owner, "#{command_class}#call"
    end
  end

  it 'writes a per-command log file into the workdir' do
    with_tmpdir do |dir|
      run_cli('-w', dir, 'status')

      assert_match(/\A\d{8}-\d{6}-status\.log\z/, ::Dir.children(::File.join(dir, 'logs')).first)
    end
  end

  it 'reports a config error as a failed check' do
    code, out, = run_cli('-c', fixture_path('config', 'bad_type.yml'), 'check')

    assert_equal 1, code
    assert_match(/^fail  config +.*pbuild\.buildjobs/, out)
  end
end
