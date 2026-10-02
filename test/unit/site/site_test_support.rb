# frozen_string_literal: true

module SiteTestSupport
  PUBLIC_ENV = { 'PACKMAN_NOVA_PUBLIC_URL' => 'https://packman.example.org/', 'PACKMAN_NOVA_WORKDIR' => '/w', 'PACKMAN_NOVA_REPO_PATH' => nil }.freeze

  def site_state
    ::JSON.parse(::File.read(fixture_path('site', 'state.json')))
  end

  def site_config(env = {})
    load_config(env: PUBLIC_ENV.merge(env))
  end
end
