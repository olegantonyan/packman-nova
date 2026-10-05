# frozen_string_literal: true

require 'fileutils'

require 'packman_nova/gpg'
require 'packman_nova/gpg/key'
require 'packman_nova/gpg/info'
require 'packman_nova/gpg/home'
require 'packman_nova/gpg/host_executor'
require 'packman_nova/gpg/container_executor'

require 'packman_nova/repo/layout'
require 'packman_nova/repo/rpm_file'
require 'packman_nova/repo/state'
require 'packman_nova/repo/retention'
require 'packman_nova/repo/build_outputs'
require 'packman_nova/repo/diff'
require 'packman_nova/repo/plan'
require 'packman_nova/repo/toolbox'
require 'packman_nova/repo/rpm_query'
require 'packman_nova/repo/signer'
require 'packman_nova/repo/createrepo'
require 'packman_nova/repo/stager'
require 'packman_nova/repo/apply'
require 'packman_nova/repo/signing_key'
require 'packman_nova/repo/repo_file'
require 'packman_nova/repo/state_builder'
require 'packman_nova/repo/outputs'
require 'packman_nova/repo/upload_order'
require 'packman_nova/repo/s3_bucket'
require 'packman_nova/repo/last_build'
require 'packman_nova/repo/cloudflare_purge'
require 'packman_nova/repo/providers/base'
require 'packman_nova/repo/providers/localfs'
require 'packman_nova/repo/providers/s3'
require 'packman_nova/repo/providers'
require 'packman_nova/repo/state_archive'
require 'packman_nova/repo/source_archive'

module PackmanNova
  class Publish
    SYNC_STATE_FILE = 'sync.json'

    def initialize(config:, logger:, out: $stdout, subprocess: nil, toolbox: nil, gpg: nil, providers: {}, manifests: nil, site_generator: nil, now: -> { ::Time.now })
      @config = config
      @logger = logger.add_filters(*config.secrets)
      @out = out
      @subprocess = subprocess || ::PackmanNova::Utils::Subprocess.new(logger: @logger)
      @toolbox = toolbox
      @gpg = gpg
      @providers = providers
      @manifests = manifests
      @site_generator = site_generator
      @now = now
    end

    def call(provider: nil, unsigned: false, dry_run: false, site: true, arch: nil)
      provider_name = provider || config.repository.provider
      guard_unsigned!(provider_name, unsigned)
      ::FileUtils.mkdir_p(workdir.tmp_dir)
      workdir.with_lock do
        key = unsigned ? nil : ::PackmanNova::Repo::SigningKey.new(config: config, gpg: gpg, logger: logger).call
        publish(build_provider(provider_name), key: key, dry_run: dry_run, site: site, arch: arch)
      end
    end

    private

    attr_reader :config, :logger, :out, :subprocess, :providers, :now

    def publish(provider, key:, dry_run:, site:, arch:)
      layout = prepare_layout(provider, dry_run)
      last_build = ::PackmanNova::Repo::LastBuild.load(workdir)
      state = ::PackmanNova::Repo::State.load(layout.state_file)
      arch = last_build.arch(arch, default: default_arch)
      diff = diff_for(last_build.record, state, layout, arch: arch, key: key, check_files: !(dry_run && provider.remote?))
      report(diff, last_build, key, dry_run: dry_run)
      dry_run ? diff : commit(provider, diff, layout, state: state, last_build: last_build, arch: arch, key: key, site: site)
    end

    def commit(provider, diff, layout, state:, last_build:, arch:, key:, site:)
      versions = ::PackmanNova::Repo::Apply.new(config: config, workdir: workdir, toolbox: toolbox).call(diff: diff, layout: layout, arch: arch, run: last_build.run, key: key)
      new_state = build_state(state, last_build.record, diff, layout, versions: versions, key: key)
      outputs.write(layout: layout, previous: state, state: new_state, key: key, site: site)
      provider.sync!(layout: layout)
      provider.archive_sources!(::PackmanNova::Repo::SourceArchive.new(manifests: manifests, workdir: workdir, logger: logger))
      diff
    end

    def prepare_layout(provider, dry_run)
      provider.prepare!(layout: ::PackmanNova::Repo::Layout.from_config(config, root: provider.root), dry_run: dry_run)
    end

    def default_arch
      config.distro.arches.first
    end

    def diff_for(record, state, layout, arch:, key:, check_files:)
      ::PackmanNova::Repo::Diff.new(
        build_record: record, results_dir: workdir.results_dir(reponame: config.pbuild.reponame, arch: arch), state: state,
        enabled: enabled_names, arch: arch, repo_dir: layout.repo_dir, key_id: key&.key_id, check_files: check_files, **repository_flags
      ).call
    end

    def enabled_names
      manifests.select(&:enabled?).map(&:name)
    end

    def repository_flags
      { publish_srpms: config.repository.publish_srpms?, publish_debuginfo: config.repository.publish_debuginfo? }
    end

    def build_state(previous, record, diff, layout, versions:, key:)
      ::PackmanNova::Repo::StateBuilder.new(
        previous: previous, build_record: record, diff: diff, layout: layout, manifests: manifests,
        sync_state: ::PackmanNova::Utils::JsonFile.read(workdir.state_file(SYNC_STATE_FILE), default: {}),
        versions: versions, key: key, now: now.call
      ).call
    end

    def report(diff, last_build, key, dry_run:)
      lines = ::PackmanNova::Repo::Plan.new(diff: diff, build_record: last_build.record, key: key).lines
      return out.puts(lines.empty? ? 'nothing to publish' : lines) if dry_run

      lines.each { |line| logger.info(line) }
      logger.info('repository files are up to date') if diff.empty?
    end

    def guard_unsigned!(provider_name, unsigned)
      return unless unsigned && provider_name == 's3' && config.signing.require_signature?

      raise ::PackmanNova::PublishError, '--unsigned is refused for the s3 provider while signing.require_signature is true'
    end

    def build_provider(name)
      providers.fetch(name) { ::PackmanNova::Repo::Providers.build(name, config: config, logger: logger) }
    end

    def outputs
      ::PackmanNova::Repo::Outputs.new(config: config, logger: logger, site_generator: site_generator)
    end

    def site_generator
      return @site_generator if @site_generator
      return unless defined?(::PackmanNova::Site::Generator) && ::PackmanNova::Site::Generator.respond_to?(:new)

      ::PackmanNova::Site::Generator
    end

    def manifests
      @manifests ||= ::PackmanNova::Manifest::Loader.new(packages_dir: config.resolve('packages'), require_checksums: false).all
    end

    def workdir
      @workdir ||= config.workdir
    end

    def gpg
      @gpg ||= ::PackmanNova::Gpg.build(config: config, logger: logger, subprocess: subprocess)
    end

    def toolbox
      @toolbox ||= ::PackmanNova::Repo::Toolbox.build(config: config, logger: logger, subprocess: subprocess)
    end
  end
end
