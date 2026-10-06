# frozen_string_literal: true

require 'test_helper'
require 'support/publish_fakes'

describe ::PackmanNova::Publish do
  let(:tmp) { ::Dir.mktmpdir('packman-nova-publish-') }
  let(:workdir) { ::File.join(tmp, 'work') }
  let(:repo) { ::File.join(tmp, 'repo') }
  let(:config) do
    load_config(
      env: {
        'PACKMAN_NOVA_WORKDIR' => workdir, 'PACKMAN_NOVA_REPO_PATH' => repo, 'PACKMAN_NOVA_PUBLIC_URL' => nil,
        'GPG_PRIVATE_KEY_BASE64' => ::PackmanNova::Gpg.to_base64(PublishFakes::PRIVATE_ARMOR)
      }
    )
  end
  let(:toolbox) { PublishFakes::Toolbox.new }
  let(:out) { ::StringIO.new }
  let(:log) { ::StringIO.new }
  let(:manifests) { [PublishFakes.manifest('fdk-aac'), PublishFakes.manifest('ffmpeg-8', kind: 'obs-link')] }
  let(:fdk) { ['libfdk-aac2-2.0.3-1699.1.nova.1.x86_64.rpm', 'fdk-aac-2.0.3-1699.1.nova.1.src.rpm'] }
  let(:ffmpeg) { ['libavcodec62-8.1.2-1699.1.nova.1.x86_64.rpm', 'ffmpeg-8-8.1.2-1699.1.nova.1.src.rpm'] }
  let(:results) { ::File.join(workdir, 'project', '_build.tumbleweed.x86_64') }
  let(:essentials) { ::File.join(repo, 'opensuse_tumbleweed', 'essentials') }

  after { ::FileUtils.rm_rf(tmp) }

  before do
    PublishFakes.results(results, 'fdk-aac' => fdk, 'ffmpeg-8' => ffmpeg)
    write_record(PublishFakes.record('fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['succeeded', ffmpeg]))
  end

  def write_record(record)
    ::PackmanNova::Utils::JsonFile.write(::File.join(workdir, 'state', 'last-build.json'), record)
  end

  def publisher(**)
    logger = ::PackmanNova::Logging::Logger.new(outputs: [log])
    ::PackmanNova::Publish.new(config:, logger:, out:, toolbox:, gpg: PublishFakes::Gpg.new, manifests:, **)
  end

  def state
    ::PackmanNova::Utils::JsonFile.read(::File.join(essentials, 'state.json'))
  end

  it 'prints the plan on a dry run without touching the repository' do
    diff = publisher.call(dry_run: true)

    assert_equal 4, diff.to_add.size
    assert_includes out.string, "add      x86_64/libfdk-aac2-2.0.3-1699.1.nova.1.x86_64.rpm\n"
    assert_includes out.string, "sign     4 file(s) with key #{PublishFakes::KEY_ID}\n"
    refute_path_exists repo
    assert_empty toolbox.calls
  end

  it 'signs, indexes and records the repository, then finds nothing to do' do
    publisher.call(site: false)

    signed = ::File.read(::File.join(essentials, 'x86_64', 'libfdk-aac2-2.0.3-1699.1.nova.1.x86_64.rpm'))

    assert_includes signed, "signed-by-#{PublishFakes::KEY_ID}"
    assert ::File.file?(::File.join(essentials, 'x86_64', 'repodata', 'repomd.xml.asc'))
    assert ::File.file?(::File.join(essentials, 'src', 'repodata', 'repomd.xml'))
    assert_equal PublishFakes::PUBLIC_ARMOR, ::File.read(::File.join(repo, 'packman-nova.key'))
    assert_includes ::File.read(::File.join(essentials, 'packman-nova.repo')), "baseurl=file://#{repo}/opensuse_tumbleweed/essentials/$basearch"
    assert_equal({ 'id' => PublishFakes::KEY_ID, 'fingerprint' => PublishFakes::FINGERPRINT }, state['key'])
    assert_equal %w[fdk-aac ffmpeg-8], state['packages'].keys
    assert_equal ['8.1.2', '1699.1.nova.1', 'openSUSE:Factory/ffmpeg-8'], state['packages']['ffmpeg-8'].values_at('version', 'release', 'origin')
    assert_equal state['packages'], ::PackmanNova::Utils::JsonFile.read(::File.join(repo, 'packages.json'))['packages']

    before = ::File.read(::File.join(essentials, 'state.json'))
    calls = toolbox.calls.size
    diff = publisher.call(site: false)

    assert_predicate diff, :empty?
    assert_equal calls, toolbox.calls.size
    assert_equal before, ::File.read(::File.join(essentials, 'state.json'))
  end

  it 'retains the last published rpms of a package whose rebuild failed' do
    publisher.call(site: false)
    ffmpeg.each { |file| ::File.delete(::File.join(results, 'ffmpeg-8', file)) }
    write_record(PublishFakes.record({ 'fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['failed', []] }, 2))
    diff = publisher.call(site: false)

    assert_equal ['ffmpeg-8'], diff.retained_packages
    assert ::File.file?(::File.join(essentials, 'x86_64', 'libavcodec62-8.1.2-1699.1.nova.1.x86_64.rpm'))
    assert_equal ['failed', '8.1.2', 1], state['packages']['ffmpeg-8'].values_at('status', 'version', 'last_run')
    assert_equal 2, state['run']
    assert_equal(2, state['files'].count { |_relative, entry| entry['package'] == 'ffmpeg-8' })
  end

  it 'publishes the build log of a failed package until it builds again' do
    ::File.write(::File.join(results, 'ffmpeg-8', '_log'), "configure\nerror: \xFF boom\n")
    record = PublishFakes.record({ 'fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['failed', []] }, 2)
    record['packages']['ffmpeg-8']['log'] = 'project/_build.tumbleweed.x86_64/ffmpeg-8/_log'
    write_record(record)
    publisher.call
    log_file = ::File.join(essentials, 'logs', 'ffmpeg-8.log')

    assert_equal "configure\nerror: � boom\n", ::File.read(log_file)
    assert_equal(['logs/ffmpeg-8.log', nil], state['packages'].values_at('ffmpeg-8', 'fdk-aac').map { |entry| entry['log'] })
    assert_includes ::File.read(::File.join(repo, 'index.html')), 'opensuse_tumbleweed/essentials/logs/ffmpeg-8.log">build log</a>'

    write_record(PublishFakes.record({ 'fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['succeeded', ffmpeg] }, 3))
    publisher.call

    refute_path_exists log_file
    assert_nil state['packages']['ffmpeg-8']['log']
  end

  it 'publishes no stale log for an unresolvable package' do
    ::File.write(::File.join(results, 'ffmpeg-8', '_log'), "old success\n")
    record = PublishFakes.record('fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['unresolvable', []])
    record['packages']['ffmpeg-8']['log'] = 'project/_build.tumbleweed.x86_64/ffmpeg-8/_log'
    write_record(record)
    publisher.call(site: false)

    refute_path_exists ::File.join(essentials, 'logs', 'ffmpeg-8.log')
  end

  it 'publishes the i586 log when the baselibs pass failed' do
    i586 = ::File.join(workdir, 'project', '_build.tumbleweed.i586', 'fdk-aac')
    ::FileUtils.mkdir_p(i586)
    ::File.write(::File.join(i586, '_log'), "i586 error\n")
    record = PublishFakes.record('fdk-aac' => ['failed', fdk], 'ffmpeg-8' => ['succeeded', ffmpeg])
    record['packages']['fdk-aac']['baselibs'] = { 'arch' => 'i586', 'code' => 'failed', 'rpms' => [] }
    write_record(record)
    publisher.call(site: false)

    assert_equal "i586 error\n", ::File.read(::File.join(essentials, 'logs', 'fdk-aac.log'))
  end

  it 'replaces rebuilt rpms and removes vanished ones' do
    publisher.call(site: false)
    ::File.write(::File.join(results, 'fdk-aac', fdk.first), 'rebuilt')
    write_record(PublishFakes.record({ 'fdk-aac' => ['succeeded', fdk], 'ffmpeg-8' => ['succeeded', [ffmpeg.last]] }, 2))
    diff = publisher.call(site: false)

    assert_equal ["x86_64/#{fdk.first}"], diff.to_replace
    assert_equal ["x86_64/#{ffmpeg.first}"], diff.to_remove
    refute_path_exists ::File.join(essentials, 'x86_64', ffmpeg.first)
    assert_equal "rebuiltsigned-by-#{PublishFakes::KEY_ID}\n", ::File.read(::File.join(essentials, 'x86_64', fdk.first))
  end

  it 'publishes unsigned to localfs but refuses unsigned s3 publishing' do
    publisher.call(unsigned: true, site: false)

    assert_nil state['key']
    refute_path_exists ::File.join(essentials, 'x86_64', 'repodata', 'repomd.xml.asc')
    assert_includes ::File.read(::File.join(essentials, 'packman-nova.repo')), "gpgcheck=0\n"
    refute_includes toolbox.scripts, ::PackmanNova::Repo::Signer::SCRIPT

    error = assert_raises(::PackmanNova::PublishError) { publisher.call(provider: 's3', unsigned: true) }
    assert_includes error.message, 'refused'
  end

  it 're-signs rpms that were published unsigned' do
    publisher.call(unsigned: true, site: false)
    diff = publisher.call(site: false)

    assert_equal 4, diff.to_resign.size
    assert(state['files'].values.all? { |entry| entry['key_id'] == PublishFakes::KEY_ID })
  end

  it 'refuses to publish without a build record' do
    ::File.delete(::File.join(workdir, 'state', 'last-build.json'))

    assert_raises(::PackmanNova::PublishError) { publisher.call }
  end

  it 'hands the state hash to the site generator' do
    generated = []
    generator = ::Class.new do
      define_method(:initialize) { |config:, state:, logger:| generated << [config, state, logger] }
      define_method(:write) { |dir, index:| generated << [dir, index] }
    end
    publisher(site_generator: generator).call

    assert_equal config, generated.first.first
    assert_equal state, generated.first[1]
    assert_equal [repo, true], generated.last
  end
end
