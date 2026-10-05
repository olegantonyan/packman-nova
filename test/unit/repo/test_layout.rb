# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Repo::Layout do
  let(:layout) { ::PackmanNova::Repo::Layout.new(root: '/srv/repo', path: '/opensuse_tumbleweed/essentials/') }

  it 'places repository files under the configured path' do
    assert_equal '/srv/repo/opensuse_tumbleweed/essentials', layout.repo_dir
    assert_equal '/srv/repo/opensuse_tumbleweed/essentials/src', layout.src_dir
    assert_equal '/srv/repo/opensuse_tumbleweed/essentials/state.json', layout.state_file
    assert_equal '/srv/repo/opensuse_tumbleweed/essentials/packman-nova.repo', layout.repo_file
    assert_equal '/srv/repo/opensuse_tumbleweed/essentials/x86_64/repodata/repomd.xml', layout.repomd('x86_64')
  end

  it 'places site files and the public key at the root' do
    assert_equal '/srv/repo/packman-nova.key', layout.public_key_file
  end

  it 'knows which keys it manages' do
    assert layout.managed?('opensuse_tumbleweed/essentials/x86_64/a.rpm')
    assert layout.managed?('index.html')
    refute layout.managed?('_state/state.tar.zst')
    refute layout.managed?('other-project/x86_64/a.rpm')
    assert_equal 'opensuse_tumbleweed/essentials/state.json', layout.state_key
  end

  it 'builds from config' do
    config = load_config(env: {})

    assert_equal '/r/opensuse_tumbleweed/essentials/packman-nova.repo', ::PackmanNova::Repo::Layout.from_config(config, root: '/r').repo_file
  end
end
