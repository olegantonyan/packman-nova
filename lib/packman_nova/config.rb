# frozen_string_literal: true

module PackmanNova
  class Config
    PROJECT_ROOT = ::File.expand_path('../..', __dir__)
    DEFAULT_PATH = ::File.join(PROJECT_ROOT, 'config', 'packman-nova.yml')
    BOOLEAN = ::PackmanNova::Config::Section::BOOLEAN
    STRINGS = [::String].freeze

    ATTRIBUTES = {
      workdir: ::String,
      offline: BOOLEAN,
      project_name: ::String,
      vendor: ::String,
      distro: {
        id: ::String, suse_version: ::Integer, arches: STRINGS, repos: STRINGS, snapshot_url: ::String,
        baselibs: { arch: ::String, repos: STRINGS }
      },
      release: { template: ::String },
      prjconf: { base_url: ::String, base_fallback: ::String, local: ::String },
      sources: {
        obs_api: ::String,
        http: { timeout_sec: ::Integer, retries: ::Integer }
      },
      container: { runtime: ::String, image: ::String, containerfile: ::String, privileged: BOOLEAN, extra_args: STRINGS },
      pbuild: {
        reponame: ::String, buildjobs: ::Integer, jobs: ::Integer, checks: BOOLEAN, debuginfo: BOOLEAN,
        repo_refresh: BOOLEAN, timeout_sec: ::Integer, extra_args: STRINGS
      },
      signing: { gpg_private_key_base64: ::String, require_signature: BOOLEAN },
      repository: {
        slug: ::String, path: ::String, public_url: ::String, publish_srpms: BOOLEAN, publish_debuginfo: BOOLEAN,
        provider: ::String,
        localfs: { path: ::String },
        s3: {
          bucket: ::String, path_in_bucket: ::String, endpoint: ::String, access_key_id: ::String,
          secret_access_key: ::String, region: ::String, force_path_style: BOOLEAN,
          cloudflare_zone_id: ::String, cloudflare_api_token: ::String
        }
      },
      site: { title: ::String, description: ::String, source_url: ::String }
    }.freeze

    class << self
      def load(path: nil, overrides: {}, cwd: ::Dir.pwd)
        ::PackmanNova::Config::Loader.new(path: path, overrides: overrides, cwd: cwd).call
      end
    end

    attr_reader :files, :env_vars_used, :env_vars_missing

    def initialize(hash, files: [], env_vars_used: [], env_vars_missing: [])
      @root = ::PackmanNova::Config::Section.new(hash, attributes: ATTRIBUTES)
      @files = files.freeze
      @env_vars_used = env_vars_used.freeze
      @env_vars_missing = env_vars_missing.freeze
      freeze
    end

    ATTRIBUTES.except(:workdir).each do |name, type|
      define_method(name) { root.public_send(name) }
      define_method(:"#{name}?") { root.public_send(name) } if type == BOOLEAN
    end

    def workdir_path
      root.workdir
    end

    def workdir
      raise ::PackmanNova::ConfigError, 'workdir is not set (PACKMAN_NOVA_WORKDIR or --workdir)' if workdir_path.empty?

      ::PackmanNova::Workdir.new(root: ::File.expand_path(workdir_path))
    end

    def secrets
      [
        signing.gpg_private_key_base64,
        repository.s3.secret_access_key,
        repository.s3.cloudflare_api_token
      ].reject(&:empty?)
    end

    def project_root
      PROJECT_ROOT
    end

    def resolve(path)
      ::File.expand_path(path, project_root)
    end

    def to_h
      root.to_h
    end

    private

    attr_reader :root
  end
end
