# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Cli::Site, :site do
  def run_site(repo_dir, options = {})
    out = ::StringIO.new
    config = site_config('PACKMAN_NOVA_REPO_PATH' => repo_dir)
    code = ::PackmanNova::Cli::Site.new(config:, logger: null_logger, options:, out:).call
    [code, out.string]
  end

  def publish_state(repo_dir)
    dir = ::File.join(repo_dir, 'opensuse_tumbleweed', 'essentials')
    ::FileUtils.mkdir_p(dir)
    ::FileUtils.cp(fixture_path('site', 'state.json'), ::File.join(dir, 'state.json'))
  end

  it 'writes the site into the repo root' do
    with_tmpdir do |dir|
      publish_state(dir)
      code, out = run_site(dir)

      assert_equal 0, code
      assert_equal "#{::File.join(dir, 'index.html')}\n#{::File.join(dir, 'packages.json')}\n", out
      assert_includes ::File.read(::File.join(dir, 'index.html')), 'libx264:x264'
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

      assert_includes error.message, "repo state not found: #{::File.join(dir, 'opensuse_tumbleweed', 'essentials', 'state.json')}"
    end
  end
end
