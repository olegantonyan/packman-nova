# frozen_string_literal: true

require 'test_helper'
require 'support/publish_fakes'

describe ::PackmanNova::Repo::Toolbox do
  let(:runtime) { ::PackmanNova::Container::Runtime.new(executable: 'podman') }
  let(:runner) { ::PackmanNova::Container::Runner.new(runtime:, logger: null_logger, subprocess: ::PackmanNova::Utils::Subprocess.new(logger: null_logger)) }
  let(:toolbox) { ::PackmanNova::Repo::Toolbox.new(runner:, image: 'img', extra_args: ['--net=none']) }

  it 'runs bash scripts with positional arguments in the builder image' do
    options = toolbox.command('echo "$@"', mounts: [::PackmanNova::Container::Mount.new(source: '/a', target: '/repo')], args: %w[x y], env: { 'K' => 'v' })

    assert_equal %w[podman run --rm --mount type=bind,source=/a,target=/repo -e K=v --entrypoint /bin/bash --net=none img -euo pipefail -c] +
                 ['echo "$@"', 'packman-nova', 'x', 'y'], runner.command(**options)
  end
end

describe ::PackmanNova::Repo::RpmQuery do
  let(:toolbox) { PublishFakes::Toolbox.new }

  it 'parses one tab-separated line per file' do
    output = "x86_64/a-1.0-2.x86_64.rpm\ta\t1:1.0-2\tx86_64\ta-1.0-2.src.rpm\tRSA/SHA256, Tue Sep 29 2026, Key ID 31d7469fd4f5f9ef\tA summary\twith tab\n"
    info = ::PackmanNova::Repo::RpmQuery.parse(output).fetch('x86_64/a-1.0-2.x86_64.rpm')

    assert_equal ['a', '1.0', '2', 'x86_64', 'a-1.0-2.src.rpm'], [info.name, info.version, info.release, info.arch, info.sourcerpm]
    assert_predicate info, :signed?
    assert_equal '31d7469fd4f5f9ef', info.key_id
    assert_equal "A summary\twith tab", info.summary
  end

  it 'reports unsigned packages' do
    info = ::PackmanNova::Repo::RpmQuery.parse("f.rpm\tb\t2-3\tnoarch\t(none)\t(none)\tB\n").fetch('f.rpm')

    refute_predicate info, :signed?
    assert_nil info.key_id
  end

  it 'queries files mounted read-only and fails on missing answers' do
    result = ::PackmanNova::Repo::RpmQuery.new(toolbox:).call(dir: '/stage', files: ['x86_64/a-1.0-2.x86_64.rpm'])
    _kind, script, mounts, _args, env = toolbox.calls.last

    assert_equal '1.0', result.fetch('x86_64/a-1.0-2.x86_64.rpm').version
    assert_equal ::PackmanNova::Repo::RpmQuery::SCRIPT, script
    assert_predicate mounts.first, :readonly?
    assert_equal ::PackmanNova::Repo::RpmQuery::FORMAT, env.fetch('QUERY_FORMAT')
    assert_empty ::PackmanNova::Repo::RpmQuery.new(toolbox:).call(dir: '/stage', files: [])

    silent = ::Object.new
    def silent.capture(*, **) = ''
    assert_raises(::PackmanNova::PublishError) { ::PackmanNova::Repo::RpmQuery.new(toolbox: silent).call(dir: '/s', files: ['a.rpm']) }
  end
end

describe ::PackmanNova::Repo::Signer do
  it 'signs with the key mounted read-only and verifies rpm -Kv output' do
    with_tmpdir do |dir|
      ::FileUtils.mkdir_p(::File.join(dir, 'x86_64'))
      ::File.write(::File.join(dir, 'x86_64', 'a-1-1.x86_64.rpm'), 'rpm')
      toolbox = PublishFakes::Toolbox.new
      ::PackmanNova::Repo::Signer.new(toolbox:).call(dir:, files: ['x86_64/a-1-1.x86_64.rpm'], key_dir: '/keys', key_id: PublishFakes::KEY_ID)
      _kind, script, mounts, args, env = toolbox.calls.last

      assert_equal ::PackmanNova::Repo::Signer::SCRIPT, script
      assert_equal([[dir, '/repo', false], ['/keys', '/gpgtmp', true]], mounts.map { |mount| [mount.source, mount.target, mount.readonly?] })
      assert_equal ['x86_64/a-1-1.x86_64.rpm'], args
      assert_equal({ 'KEY_ID' => PublishFakes::KEY_ID, 'GPG_TTY' => '/dev/null' }, env)
    end
  end

  it 'raises when rpm -Kv does not confirm the signature' do
    with_tmpdir do |dir|
      ::File.write(::File.join(dir, 'a.rpm'), 'rpm')
      signer = ::PackmanNova::Repo::Signer.new(toolbox: PublishFakes::Toolbox.new(verify: 'NOKEY'))

      assert_raises(::PackmanNova::PublishError) { signer.call(dir:, files: ['a.rpm'], key_dir: '/k', key_id: PublishFakes::KEY_ID) }
    end
  end

  it 'writes the private key 0600 into the key dir' do
    with_tmpdir do |dir|
      ::PackmanNova::Repo::Signer.write_key_dir(dir, PublishFakes.key)

      assert_equal 0o600, ::File.stat(::File.join(dir, 'key.priv')).mode & 0o777
      assert_equal PublishFakes::PUBLIC_ARMOR, ::File.read(::File.join(dir, 'key.pub'))
    end
  end
end

describe ::PackmanNova::Repo::Createrepo do
  it 'creates metadata for each dir and signs it only with a key' do
    with_tmpdir do |dir|
      toolbox = PublishFakes::Toolbox.new
      createrepo = ::PackmanNova::Repo::Createrepo.new(toolbox:)
      createrepo.call(repo_dir: dir, dirs: %w[x86_64 src], key_dir: '/keys')

      assert ::File.file?(::File.join(dir, 'src', 'repodata', 'repomd.xml.asc'))
      assert_equal({ 'SIGN' => '1' }, toolbox.calls.last.last)
      assert_equal %w[x86_64 src], toolbox.calls.last[3]

      createrepo.call(repo_dir: dir, dirs: %w[x86_64], key_dir: nil)

      assert_equal({ 'SIGN' => '' }, toolbox.calls.last.last)
      assert_equal ['/repo'], toolbox.calls.last[2].map(&:target)
    end
  end

  it 'keeps the documented createrepo_c and gpg invocations' do
    assert_includes ::PackmanNova::Repo::Createrepo::SCRIPT, 'createrepo_c --update --retain-old-md=0 --compatibility .'
    assert_includes ::PackmanNova::Repo::Createrepo::SCRIPT, 'gpg --batch --no-tty --detach-sign --armor --yes --always-trust -o repodata/repomd.xml.asc repodata/repomd.xml'
    assert_includes ::PackmanNova::Repo::Signer::SCRIPT, %(rpm --define '_signature gpg' --define "_gpg_name $KEY_ID" --addsign "$@")
  end
end
