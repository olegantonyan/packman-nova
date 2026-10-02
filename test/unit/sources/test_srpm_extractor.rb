# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Sources::SrpmExtractor do
  let(:config) { load_config(env: { 'PACKMAN_NOVA_WORKDIR' => '/w', 'PACKMAN_NOVA_CONTAINER_RUNTIME' => nil }) }
  let(:runner) { ::PackmanNova::Container::Runner.new(runtime: ::PackmanNova::Container::Runtime.new(executable: 'podman'), logger: null_logger, subprocess: nil) }

  def fake_image(exists:)
    ::Struct.new(:tag, :present) { def exists? = present }.new('localhost/packman-nova-builder:latest', exists)
  end

  def extractor(exists: true)
    ::PackmanNova::Sources::SrpmExtractor.new(config: config, logger: null_logger, workdir: config.workdir, runner: runner, image: fake_image(exists: exists))
  end

  it 'runs rpm2cpio and cpio inside the builder image with the srpm dir mounted read-only' do
    argv = extractor.command(srpm: '/w/cache/mirror-src/a-1-1.src.rpm', member: 'a-1.tar.gz', out_dir: '/w/tmp/o')

    assert_equal [
      'podman', 'run', '--rm', '--mount', 'type=bind,source=/w/cache/mirror-src,target=/in,readonly', '--mount', 'type=bind,source=/w/tmp/o,target=/out',
      '--entrypoint', '/bin/sh', '--network', 'none', 'localhost/packman-nova-builder:latest',
      '-c', ::PackmanNova::Sources::SrpmExtractor::SCRIPT, 'sh', '/in/a-1-1.src.rpm', 'a-1.tar.gz', '/out/member'
    ], argv
  end

  it 'asks for an image build when the builder image is missing' do
    error = assert_raises(::PackmanNova::SyncError) { extractor(exists: false).extract(srpm: '/w/a.src.rpm', member: 'a', target: '/w/a') }

    assert_match(/packman-nova image build/, error.message)
  end
end
