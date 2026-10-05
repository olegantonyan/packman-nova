# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Container::Runtime do
  let(:config) { load_config(env: { 'PACKMAN_NOVA_CONTAINER_RUNTIME' => nil }) }

  it 'prefers the environment variable' do
    configured = load_config(env: { 'PACKMAN_NOVA_CONTAINER_RUNTIME' => 'docker' })
    runtime = ::PackmanNova::Container::Runtime.detect(config: configured, probe: ->(_) { flunk })

    assert_equal 'docker', runtime.executable
  end

  it 'probes podman before docker when set to auto' do
    probed = []
    runtime = ::PackmanNova::Container::Runtime.detect(config:, probe: ->(exe) { (probed << exe) && exe == 'docker' })

    assert_equal 'docker', runtime.executable
    assert_equal %w[podman docker], probed
  end

  it 'raises ConfigError when nothing is installed' do
    assert_raises(::PackmanNova::ConfigError) { ::PackmanNova::Container::Runtime.detect(config:, probe: ->(_) { false }) }
  end

  it 'builds removal commands for podman and docker' do
    podman = ::PackmanNova::Container::Runtime.new(executable: 'podman')
    docker = ::PackmanNova::Container::Runtime.new(executable: 'docker')

    assert_equal %w[podman unshare rm -rf /w/build-root], podman.remove_tree_argv('/w/build-root', image: 'img')
    assert_equal ['docker', 'run', '--rm', '-v', '/w:/x', 'img', 'rm', '-rf', '/x/build-root'], docker.remove_tree_argv('/w/build-root', image: 'img')
  end
end

describe ::PackmanNova::Container::Mount do
  it 'renders bind mount arguments' do
    assert_equal ['--mount', 'type=bind,source=/a,target=/b'], ::PackmanNova::Container::Mount.new(source: '/a', target: '/b').to_args
    assert_equal ['--mount', 'type=bind,source=/a,target=/b,readonly'], ::PackmanNova::Container::Mount.new(source: '/a', target: '/b', readonly: true).to_args
  end

  it 'rejects commas in paths' do
    assert_raises(::ArgumentError) { ::PackmanNova::Container::Mount.new(source: '/a,b', target: '/b') }
  end
end

describe ::PackmanNova::Container::Runner do
  let(:runtime) { ::PackmanNova::Container::Runtime.new(executable: 'podman') }
  let(:runner) { ::PackmanNova::Container::Runner.new(runtime:, logger: null_logger, subprocess: ::PackmanNova::Utils::Subprocess.new(logger: null_logger)) }

  it 'builds the full run command' do
    argv = runner.command(
      image: 'localhost/img:latest', args: %w[pbuild /project], privileged: true, name: 'nova-1',
      mounts: [::PackmanNova::Container::Mount.new(source: '/w/project', target: '/project')], env: { 'LANG' => 'C.UTF-8' }
    )

    assert_equal %w[
      podman run --rm --privileged --name nova-1 --mount type=bind,source=/w/project,target=/project
      -e LANG=C.UTF-8 localhost/img:latest pbuild /project
    ], argv
  end

  it 'builds a minimal run command' do
    assert_equal %w[podman run --rm img true], runner.command(image: 'img', args: ['true'])
  end
end

describe ::PackmanNova::Container::Image do
  it 'builds the image build command from config' do
    config = load_config(env: {})
    image = ::PackmanNova::Container::Image.new(
      runtime: ::PackmanNova::Container::Runtime.new(executable: 'podman'), config:, logger: null_logger,
      subprocess: ::PackmanNova::Utils::Subprocess.new(logger: null_logger), workdir: ::PackmanNova::Workdir.new(root: '/w')
    )
    containerfile = config.resolve('container/Containerfile')

    assert_equal ['podman', 'build', '--no-cache', '-t', 'localhost/packman-nova-builder:latest', '-f', containerfile, ::File.dirname(containerfile)],
                 image.build_command(no_cache: true)
  end
end
