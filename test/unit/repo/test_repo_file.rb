# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Repo::RepoFile do
  it 'renders the design .repo file for a public URL' do
    config = load_config(env: { 'PACKMAN_NOVA_PUBLIC_URL' => 'https://packman.omnipackage.org/' })

    assert_equal <<~REPO, ::PackmanNova::Repo::RepoFile.new(config:, layout: ::PackmanNova::Repo::Layout.from_config(config, root: '/ignored')).render
      [packman-nova-essentials]
      name=packman-nova Essentials (openSUSE Tumbleweed)
      type=rpm-md
      baseurl=https://packman.omnipackage.org/opensuse_tumbleweed/essentials/$basearch
      gpgcheck=1
      gpgkey=https://packman.omnipackage.org/packman-nova.key
      enabled=1
      autorefresh=1
      priority=80
    REPO
  end

  it 'matches the repo file shipped by packman-nova-keyring' do
    config = load_config(env: { 'PACKMAN_NOVA_PUBLIC_URL' => 'https://packman.omnipackage.org' })
    shipped = ::File.join(::PackmanNova::Config::PROJECT_ROOT, 'packages', 'packman-nova-keyring', ::PackmanNova::Repo::Layout::REPO_FILE)

    assert_equal ::File.read(shipped), ::PackmanNova::Repo::RepoFile.new(config:, layout: ::PackmanNova::Repo::Layout.from_config(config, root: '/ignored')).render
  end

  it 'falls back to a file URL of the localfs root and disables gpgcheck when unsigned' do
    config = load_config(env: { 'PACKMAN_NOVA_PUBLIC_URL' => nil })
    text = ::PackmanNova::Repo::RepoFile.new(config:, layout: ::PackmanNova::Repo::Layout.from_config(config, root: '/srv/repo/'), signed: false).render

    assert_includes text, "baseurl=file:///srv/repo/opensuse_tumbleweed/essentials/$basearch\n"
    assert_includes text, "gpgkey=file:///srv/repo/packman-nova.key\n"
    assert_includes text, "gpgcheck=0\n"
  end
end
