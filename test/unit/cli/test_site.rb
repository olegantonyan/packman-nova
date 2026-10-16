# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Cli::Site, :site do
  def run_site(repo_dir, options = {})
    out = ::StringIO.new
    config = site_config('PACKMAN_NOVA_REPO_PATH' => repo_dir)
    code = ::PackmanNova::Cli::Site.new(config:, logger: null_logger, options:, out:).call
    [code, out.string]
  end

  def publish_state(repo_dir, distro = 'opensuse_tumbleweed')
    dir = ::File.join(repo_dir, distro, 'essentials')
    ::FileUtils.mkdir_p(dir)
    ::FileUtils.cp(fixture_path('site', 'state.json'), ::File.join(dir, 'state.json'))
  end

  it 'writes the site into the repo root' do
    with_tmpdir do |dir|
      publish_state(dir)
      code, out = run_site(dir)

      assert_equal 0, code
      assert_equal "#{::File.join(dir, 'index.html')}\n", out
      assert_includes ::File.read(::File.join(dir, 'index.html')), 'libx264:x264'
    end
  end

  it 'renders every distro with a published state' do
    with_tmpdir do |dir|
      publish_state(dir)
      publish_state(dir, 'opensuse_leap_16.1')
      run_site(dir)
      html = ::File.read(::File.join(dir, 'index.html'))

      assert_includes html, 'id="opensuse_leap_16.1-pkg-vlc"'
      assert_includes html, 'id="opensuse_tumbleweed-pkg-vlc"'
      assert_includes html, 'Not published yet.'
    end
  end

  it 'uploads only index.html through a provider' do
    with_tmpdir do |dir|
      publish_state(dir)
      provider = ::PackmanNova::Repo::Providers::Localfs.new(root: dir, logger: null_logger)
      uploaded = []
      provider.define_singleton_method(:publish_root_files!) { |keys| uploaded.concat(keys) }
      command = ::PackmanNova::Cli::Site.new(config: site_config('PACKMAN_NOVA_REPO_PATH' => dir), logger: null_logger, options: { provider: 'localfs' }, out: ::StringIO.new)
      command.define_singleton_method(:provider) { provider }
      command.call

      assert_equal ['index.html'], uploaded
    end
  end

  it 'writes into --output' do
    with_tmpdir do |dir|
      publish_state(dir)
      output = ::File.join(dir, 'preview')
      run_site(dir, output:)

      assert_path_exists ::File.join(output, 'index.html')
      refute_path_exists ::File.join(dir, 'index.html')
    end
  end

  it 'fails clearly without a repo state' do
    with_tmpdir do |dir|
      error = assert_raises(::PackmanNova::Error) { run_site(dir) }

      assert_includes error.message, "no published repo state for any of opensuse_tumbleweed, opensuse_leap_16.0, opensuse_leap_16.1 under #{dir}"
    end
  end
end
