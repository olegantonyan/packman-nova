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
require 'packman_nova/repo/build_outputs'
require 'packman_nova/repo/diff'
require 'packman_nova/repo/toolbox'
require 'packman_nova/repo/rpm_query'
require 'packman_nova/repo/signer'
require 'packman_nova/repo/createrepo'
require 'packman_nova/repo/apply'
require 'packman_nova/repo/repo_file'
require 'packman_nova/repo/state_builder'
require 'packman_nova/repo/build_logs'
require 'packman_nova/repo/install_check'
require 'packman_nova/repo/s3_bucket'
require 'packman_nova/repo/cloudflare_purge'
require 'packman_nova/repo/providers/base'
require 'packman_nova/repo/providers/localfs'
require 'packman_nova/repo/providers/s3'
require 'packman_nova/repo/providers'
require 'packman_nova/repo/state_archive'
require 'packman_nova/repo/source_archive'

module PackmanNova
  class Publish
    def initialize(config:, logger:, out: $stdout, subprocess: nil, toolbox: nil, gpg: nil, providers: {}, manifests: nil, site_generator: nil, now: -> { ::Time.now })
      @config = config
      @logger = logger
      @out = out
      @subprocess = subprocess || ::PackmanNova::Utils::Subprocess.new(logger: @logger)
      @toolbox = toolbox
      @gpg = gpg
      @providers = providers
      @manifests = manifests
      @site_generator = site_generator || ::PackmanNova::Site::Generator
      @now = now
    end

    def uninstallable
      @uninstallable || {}
    end

    def call(provider: nil, unsigned: false, dry_run: false, site: true, arch: nil)
      provider_name = provider || config.repository.provider
      guard_unsigned!(provider_name, unsigned)
      ::FileUtils.mkdir_p(workdir.tmp_dir)
      workdir.with_lock do
        key = unsigned ? nil : signing_key
        publish(build_provider(provider_name), key:, dry_run:, site:, arch:)
      end
    end

    private

    attr_reader :config, :logger, :out, :subprocess, :providers, :site_generator, :now

    def publish(provider, key:, dry_run:, site:, arch:)
      layout = prepare_layout(provider, dry_run)
      record = ::PackmanNova::State::BuildRecord.new(workdir:).last!
      state = ::PackmanNova::Repo::State.load(layout.state_file)
      arch = publish_arch(record['arch'], arch)
      diff = diff_for(record, state, layout, arch:, key:, check_files: !(dry_run && provider.remote?))
      report(diff, record, key, dry_run:)
      dry_run ? diff : commit(provider, diff, layout, state:, record:, arch:, key:, site:)
    end

    def commit(provider, diff, layout, state:, record:, arch:, key:, site:)
      versions = ::PackmanNova::Repo::Apply.new(config:, workdir:, toolbox:).call(diff:, layout:, arch:, run: record['run'], key:)
      @uninstallable = install_problems(diff, layout, arch)
      new_state = build_state(state, record, diff, layout, versions:, key:)
      write_outputs(layout, state, new_state, key, site)
      provider.sync!(layout:)
      provider.archive_sources!(::PackmanNova::Repo::SourceArchive.new(manifests:, workdir:, logger:))
      diff
    end

    def signing_key
      private_armor = ::PackmanNova::Gpg.to_armor(encoded_private_key)
      info = gpg.info(private_armor)
      raise ::PackmanNova::PublishError, 'GPG_PRIVATE_KEY_BASE64 does not hold a private key' unless info.secret?

      logger.info("signing with key #{info.key_id} (#{info.uids.join(', ')})")
      ::PackmanNova::Gpg::Key.new(private_armor:, public_armor: gpg.public_key_from_private(private_armor), key_id: info.key_id, fingerprint: info.fingerprint)
    end

    def encoded_private_key
      encoded = config.signing.gpg_private_key_base64
      raise ::PackmanNova::PublishError, 'signing.gpg_private_key_base64 (GPG_PRIVATE_KEY_BASE64) is empty; set it or pass --unsigned' if encoded.empty?

      encoded
    end

    def write_outputs(layout, previous, state, key, site)
      state = persist_state(layout, previous, state)
      write_repo_files(layout, key)
      site_generator.new(config:, state: state.to_h, logger:).write(layout.root, index: site)
    end

    def write_repo_files(layout, key)
      ::PackmanNova::Utils::Path.atomic_write(layout.repo_file, ::PackmanNova::Repo::RepoFile.new(config:, layout:, signed: !key.nil?).render)
      ::PackmanNova::Utils::Path.atomic_write(layout.public_key_file, key.public_armor) if key
    end

    def persist_state(layout, previous, state)
      return previous if previous.same_content?(state) && ::File.file?(layout.state_file)

      state.write(layout.state_file)
      state
    end

    def prepare_layout(provider, dry_run)
      provider.prepare!(layout: ::PackmanNova::Repo::Layout.from_config(config, root: provider.root), dry_run:)
    end

    def diff_for(record, state, layout, arch:, key:, check_files:)
      ::PackmanNova::Repo::Diff.new(
        build_record: record, results_dir: results_dir(arch), baselibs_dir: results_dir(config.distro.baselibs.arch), state:,
        enabled: enabled_names, arch:, repo_dir: layout.repo_dir, key_id: key&.key_id, check_files:, **repository_flags
      ).call
    end

    def results_dir(arch)
      config.results_dir(arch) unless arch.empty?
    end

    def enabled_names
      manifests.select(&:enabled?).map(&:name)
    end

    def repository_flags
      { publish_srpms: config.repository.publish_srpms?, publish_debuginfo: config.repository.publish_debuginfo? }
    end

    def build_state(previous, record, diff, layout, versions:, key:)
      ::PackmanNova::Repo::StateBuilder.new(
        previous:, build_record: record, diff:, layout:, manifests:,
        sync_packages: ::PackmanNova::Sync::State.new(workdir:).packages,
        versions:, key:, now: now.call,
        package_fields: { 'log' => ::PackmanNova::Repo::BuildLogs.new(config:).call(layout:, record:), 'uninstallable' => uninstallable }
      ).call
    end

    def install_problems(diff, layout, arch)
      return {} unless install_check?

      install_check.by_package(layout:, arch:, repos: config.distro.repos, desired: diff.desired)
    rescue ::PackmanNova::Error => e
      logger.warn("installcheck skipped: #{e.message.lines.first&.strip}")
      {}
    end

    def install_check?
      return false unless config.repository.installcheck.enabled?
      return true unless config.offline?

      logger.warn('installcheck skipped: offline')
      false
    end

    def install_check
      ::PackmanNova::Repo::InstallCheck.new(
        toolbox:, downloader: ::PackmanNova::Sources::Downloader.from_config(config:, logger:), workdir:, logger:,
        allow_missing: config.repository.installcheck.allow_missing
      )
    end

    def publish_arch(recorded, requested)
      raise ::PackmanNova::PublishError, "--arch #{requested} does not match the last build (#{recorded})" if requested && recorded && requested != recorded

      requested || recorded || config.distro.arches.first
    end

    def report(diff, record, key, dry_run:)
      lines = plan_lines(diff, record, key)
      return out.puts(lines.empty? ? 'nothing to publish' : lines) if dry_run

      lines.each { |line| logger.info(line) }
      logger.info('repository files are up to date') if diff.empty?
    end

    def plan_lines(diff, record, key)
      files = { 'add' => diff.to_add, 'replace' => diff.to_replace, 'remove' => diff.to_remove, 'resign' => diff.to_resign }
      [
        *files.flat_map { |action, list| list.map { |relative| "#{action.ljust(8)} #{relative}" } }, *sign_lines(diff, key),
        *diff.retained_packages.map { |name| "retain   #{name} (#{record.dig('packages', name, 'code') || 'not built'})" },
        *diff.ignored.map { |reason| "ignore   #{reason}" }
      ]
    end

    def sign_lines(diff, key)
      key && !diff.to_stage.empty? ? ["sign     #{diff.to_stage.size} file(s) with key #{key.key_id}"] : []
    end

    def guard_unsigned!(provider_name, unsigned)
      return unless unsigned && provider_name == 's3' && config.signing.require_signature?

      raise ::PackmanNova::PublishError, '--unsigned is refused for the s3 provider while signing.require_signature is true'
    end

    def build_provider(name)
      providers.fetch(name) { ::PackmanNova::Repo::Providers.build(name, config:, logger:) }
    end

    def manifests
      @manifests ||= ::PackmanNova::Manifest::Loader.new(packages_dir: config.packages_dir, require_checksums: false).all
    end

    def workdir
      @workdir ||= config.workdir
    end

    def gpg
      @gpg ||= ::PackmanNova::Gpg.build(config:, logger:, subprocess:)
    end

    def toolbox
      @toolbox ||= ::PackmanNova::Repo::Toolbox.build(config:, logger:, subprocess:)
    end
  end
end
