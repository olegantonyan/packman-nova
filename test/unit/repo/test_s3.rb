# frozen_string_literal: true

require 'test_helper'
require 'aws-sdk-s3'
require 'digest'

describe ::PackmanNova::Repo::Providers::S3 do
  let(:client) { ::Aws::S3::Client.new(stub_responses: true, region: 'auto', credentials: ::Aws::Credentials.new('id', 'secret')) }
  let(:remote) { {} }
  let(:purged) { [] }
  let(:purger) { ->(prefix) { purged << prefix } }
  let(:root) { ::Dir.mktmpdir('packman-nova-s3-') }
  let(:layout) { ::PackmanNova::Repo::Layout.new(root:, path: 'tw/ess') }
  let(:bucket) { ::PackmanNova::Repo::S3Bucket.new(client:, name: 'repositories', prefix: '/packman/') }
  let(:provider) { ::PackmanNova::Repo::Providers::S3.new(root:, logger: null_logger, bucket:, purger:, public_url: 'https://cdn.example.org/packman/') }

  after { ::FileUtils.rm_rf(root) }

  before do
    objects = remote
    client.stub_responses(:list_objects_v2, lambda { |context|
      prefix = context.params[:prefix]
      contents = objects.select { |key, _body| key.start_with?(prefix) }.map do |key, body|
        { key:, size: body.bytesize, etag: %("#{::Digest::MD5.hexdigest(body)}") }
      end
      { contents:, is_truncated: false }
    })
    client.stub_responses(:get_object, ->(context) { { body: objects.fetch(context.params[:key]) } })
  end

  def write(key, content)
    path = ::File.join(root, key)
    ::FileUtils.mkdir_p(::File.dirname(path))
    ::File.write(path, content)
  end

  def requests(operation)
    client.api_requests.select { |request| request[:operation_name] == operation }.map { |request| request[:params] }
  end

  it 'lists, uploads, downloads and deletes under the bucket prefix' do
    remote['packman/tw/ess/a.rpm'] = 'rpm'
    write('local.rpm', 'data')

    assert_equal({ 'tw/ess/a.rpm' => { size: 3, etag: ::Digest::MD5.hexdigest('rpm') } }, provider.bucket.list('tw/'))
    provider.bucket.download('tw/ess/a.rpm', ::File.join(root, 'down', 'a.rpm'))
    provider.bucket.upload(::File.join(root, 'local.rpm'), 'tw/ess/x86_64/local.rpm')
    provider.bucket.upload(::File.join(root, 'local.rpm'), 'tw/ess/logs/vlc.log')
    provider.bucket.delete(%w[tw/ess/a.rpm])

    assert_equal 'rpm', ::File.read(::File.join(root, 'down', 'a.rpm'))
    assert_equal([['packman/tw/ess/x86_64/local.rpm', 'application/x-rpm'], ['packman/tw/ess/logs/vlc.log', 'text/plain; charset=utf-8']],
                 requests(:put_object).map { |params| [params[:key], params[:content_type]] })
    assert_equal [{ key: 'packman/tw/ess/a.rpm' }], requests(:delete_objects).first[:delete][:objects]
    assert provider.bucket.exist?('tw/ess/a.rpm')
    refute provider.bucket.exist?('tw/ess/b.rpm')
  end

  it 'mirrors managed remote objects and prunes stale local files' do
    remote.merge!('packman/tw/ess/x86_64/a.rpm' => 'rpm', 'packman/index.html' => 'html', 'packman/_state/state.tar.zst' => 'state', 'packman/other/x.rpm' => 'x')
    write('tw/ess/x86_64/a.rpm', 'old')
    write('tw/ess/x86_64/gone.rpm', 'gone')
    provider.prepare!(layout:)

    assert_equal 'rpm', ::File.read(::File.join(root, 'tw/ess/x86_64/a.rpm'))
    assert_equal 'html', ::File.read(::File.join(root, 'index.html'))
    refute_path_exists ::File.join(root, 'tw/ess/x86_64/gone.rpm')
    refute_path_exists ::File.join(root, '_state/state.tar.zst')
    refute_path_exists ::File.join(root, 'other/x.rpm')
  end

  it 'fetches only state.json on a dry run' do
    remote.merge!('packman/tw/ess/state.json' => '{}', 'packman/tw/ess/x86_64/a.rpm' => 'rpm')
    provider.prepare!(layout:, dry_run: true)

    assert_equal '{}', ::File.read(layout.state_file)
    refute_path_exists ::File.join(root, 'tw/ess/x86_64/a.rpm')
  end

  it 'uploads changed files in repository order, deletes last and purges the CDN' do
    remote.merge!('packman/tw/ess/x86_64/same.rpm' => 'same', 'packman/tw/ess/x86_64/old.rpm' => 'old', 'packman/_state/state.tar.zst' => 's', 'packman/_sources/sha256/a' => 'a')
    {
      'tw/ess/x86_64/same.rpm' => 'same', 'tw/ess/x86_64/new.rpm' => 'new', 'tw/ess/x86_64/repodata/repomd.xml' => 'md',
      'tw/ess/x86_64/repodata/repomd.xml.asc' => 'asc', 'tw/ess/x86_64/repodata/repomd.xml.key' => 'key', 'tw/ess/x86_64/repodata/p-primary.xml.zst' => 'p',
      'tw/ess/packman-nova.repo' => 'repo', 'tw/ess/state.json' => '{}', 'index.html' => 'i', 'packages.json' => '{}', 'packman-nova.key' => 'k'
    }.each { |key, content| write(key, content) }
    provider.sync!(layout:)

    assert_equal(%w[
      tw/ess/x86_64/new.rpm tw/ess/x86_64/repodata/p-primary.xml.zst tw/ess/x86_64/repodata/repomd.xml tw/ess/x86_64/repodata/repomd.xml.asc
      tw/ess/x86_64/repodata/repomd.xml.key tw/ess/packman-nova.repo tw/ess/state.json index.html packages.json packman-nova.key
    ].map { |key| "packman/#{key}" }, requests(:put_object).map { |params| params[:key] })
    assert_equal [{ key: 'packman/tw/ess/x86_64/old.rpm' }], requests(:delete_objects).first[:delete][:objects]
    assert_equal ['cdn.example.org/packman'], purged
  end

  it 'does nothing and skips the purge when the mirror matches' do
    remote['packman/tw/ess/x86_64/same.rpm'] = 'same'
    write('tw/ess/x86_64/same.rpm', 'same')
    provider.sync!(layout:)

    assert_empty requests(:put_object)
    assert_empty requests(:delete_objects)
    assert_empty purged
  end

  it 'archives cached sources of enabled packages that the bucket lacks' do
    with_tmpdir do |dir|
      workdir = ::PackmanNova::Workdir.new(root: dir)
      have, need, uncached = %w[have need uncached].map { |content| ::Digest::SHA256.hexdigest(content) }
      [[have, 'have'], [need, 'need']].each do |sha256, content|
        ::FileUtils.mkdir_p(::File.dirname(workdir.cache_blob(sha256:)))
        ::File.write(workdir.cache_blob(sha256:), content)
      end
      remote["packman/_sources/sha256/#{have}"] = 'have'
      source = ->(sha256, **extra) { ::PackmanNova::Manifest::Source.new(file: 'f', sha256:, **extra) }
      package = ::Data.define(:enabled?, :sources)
      manifests = [
        package.new(true, [source.call(have), source.call(need), source.call(uncached), source.call(nil, path: 'x'), source.call(nil, generated: 'public-key')]),
        package.new(false, [source.call(::Digest::SHA256.hexdigest('disabled'))])
      ]
      logger, log = string_logger
      uploaded = provider.archive_sources!(::PackmanNova::Repo::SourceArchive.new(manifests:, workdir:, logger:))

      assert_equal [need], uploaded
      assert_equal([["packman/_sources/sha256/#{need}", 'application/octet-stream']], requests(:put_object).map { |params| params.values_at(:key, :content_type) })
      assert_includes log.string, "#{uncached}) is not in the cache"
    end
  end

  it 'builds a client from config and validates required settings' do
    with_tmpdir do |dir|
      env = {
        'PACKMAN_NOVA_WORKDIR' => dir, 'CLOUDFLARE_R2_BUCKET' => 'b', 'CLOUDFLARE_R2_ENDPOINT' => 'https://r2.example.invalid',
        'CLOUDFLARE_R2_ACCESS_KEY_ID' => 'id', 'CLOUDFLARE_R2_SECRET_ACCESS_KEY' => 'secret', 'CLOUDFLARE_ZONE_ID' => nil, 'CLOUDFLARE_API_TOKEN' => nil
      }
      built = ::PackmanNova::Repo::Providers::S3.build(config: load_config(env:), logger: null_logger)
      client_config = built.bucket.send(:client).config

      assert_equal ::File.join(dir, 'repo-mirror'), built.root
      assert_equal 'auto', client_config.region
      assert client_config.force_path_style
      assert_equal 'adaptive', client_config.retry_mode
      assert_equal 10, client_config.max_attempts
      assert_equal 'when_required', client_config.request_checksum_calculation
      assert_raises(::PackmanNova::ConfigError) { ::PackmanNova::Repo::Providers::S3.build(config: load_config(env: env.merge('CLOUDFLARE_R2_BUCKET' => nil)), logger: null_logger) }
    end
  end
end

describe ::PackmanNova::Repo::CloudflarePurge do
  let(:server) { ::HttpStubServer.new }

  after { server.stop }

  it 'posts a prefix purge and reports success' do
    server.on('/zones/zone1/purge_cache', body: '{"success":true}')
    logger, io = string_logger

    assert ::PackmanNova::Repo::CloudflarePurge.new(zone_id: 'zone1', api_token: 'tok', logger:, api: server.url('')).call('cdn.example.org/p')
    assert_equal ['POST', '/zones/zone1/purge_cache'], server.requests.pop
    assert_includes io.string, 'purged cache for cdn.example.org/p'
  end

  it 'warns instead of failing' do
    server.on('/zones/zone1/purge_cache', status: 403, body: '{"success":false}')
    logger, io = string_logger

    refute ::PackmanNova::Repo::CloudflarePurge.new(zone_id: 'zone1', api_token: 'tok', logger:, api: server.url('')).call('x')
    assert_includes io.string, 'HTTP 403'
  end
end
