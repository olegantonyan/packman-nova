# frozen_string_literal: true

require 'packman_nova/upstream/version_compare'
require 'packman_nova/upstream/version_text'
require 'packman_nova/upstream/probe'
require 'packman_nova/upstream/result'
require 'packman_nova/upstream/snapshot'
require 'packman_nova/upstream/http_probe'
require 'packman_nova/upstream/git_probe'
require 'packman_nova/upstream/git_snapshot'
require 'packman_nova/upstream/spec_file'
require 'packman_nova/upstream/changes_entry'
require 'packman_nova/upstream/manifest_text'
require 'packman_nova/upstream/package_updater'

module PackmanNova
  class Upstream
    ERRORS = [::PackmanNova::Error, ::SystemCallError].freeze

    def initialize(config:, logger:, packages_dir: nil, services: nil, clock: -> { ::Time.now })
      @config = config
      @logger = logger
      @packages_dir = packages_dir || config.packages_dir
      @services = services
      @clock = clock
    end

    def check(packages: nil)
      ensure_online!
      manifests(packages).map { |manifest| guarded(manifest) { |current, probe| probed(manifest, current, probe) } }
    end

    def update(packages: nil, version: nil)
      validate_update!(packages, version)
      workdir.with_lock do
        workdir.prepare!
        manifests(packages).map { |manifest| guarded(manifest, version:) { |current, probe| apply(manifest, current, probe, version) } }
      end
    end

    private

    attr_reader :config, :logger, :packages_dir, :clock

    def ensure_online!
      raise ::PackmanNova::UpstreamError, 'upstream probing needs the network (--offline is set)' if config.offline?
    end

    def validate_update!(packages, version)
      ensure_online!
      raise ::PackmanNova::ConfigError, 'packager is not set' if config.packager.empty?
      raise ::PackmanNova::UpstreamError, '--version needs exactly one --package' if version && packages.to_a.uniq.size != 1
    end

    def manifests(names)
      loader = ::PackmanNova::Manifest::Loader.new(packages_dir:, require_checksums: false)
      names ? names.uniq.map { |name| loader.find(name) } : loader.all.select { |manifest| manifest.enabled? && manifest.native? }
    end

    def guarded(manifest, version: nil)
      skip = skip_reason(manifest)
      return result(manifest, :skipped, detail: skip) if skip

      current = current_version(manifest)
      yield current, probe(manifest.watch, version)
    rescue *ERRORS => e
      result(manifest, :failed, detail: e.message.lines.first.to_s.strip)
    end

    def skip_reason(manifest)
      return "obs-link, follows #{manifest.origin} through sync" if manifest.obs_link?

      'no watch' unless manifest.watch
    end

    def probed(manifest, current, probe)
      result(manifest, outdated?(manifest.watch, current, probe) ? :outdated : :ok, current:, latest: probe.label)
    end

    def apply(manifest, current, probe, version)
      return probed(manifest, current, probe) unless version || outdated?(manifest.watch, current, probe)

      updated = updater(manifest).call(probe)
      result(manifest, :updated, current:, latest: updated)
    end

    def outdated?(watch, current, probe)
      return probe.commit != watch.commit if watch.branch?

      ::PackmanNova::Upstream::VersionCompare.compare(probe.version, current).positive?
    end

    def result(manifest, state, **)
      ::PackmanNova::Upstream::Result.new(name: manifest.name, state:, **)
    end

    def current_version(manifest)
      spec = ::PackmanNova::Upstream::SpecFile.new(::File.read(::File.join(manifest.dir, manifest.spec_name)))
      spec.version || raise(::PackmanNova::UpstreamError, "#{manifest.spec_name}: no Version: line")
    end

    def probe(watch, version)
      watch.http? ? http_probe.call(watch, version:) : git_probe.call(watch, version:)
    end

    def updater(manifest)
      ::PackmanNova::Upstream::PackageUpdater.new(
        manifest:, fetcher: services.fetcher, snapshots:, logger:,
        changes: ::PackmanNova::Upstream::ChangesEntry.new(packager: config.packager, clock:)
      )
    end

    def http_probe
      @http_probe ||= ::PackmanNova::Upstream::HttpProbe.new(downloader: services.downloader)
    end

    def git_probe
      @git_probe ||= ::PackmanNova::Upstream::GitProbe.new(subprocess:)
    end

    def snapshots
      @snapshots ||= ::PackmanNova::Upstream::GitSnapshot.new(workdir:, cache: services.cache, subprocess:, logger:)
    end

    def services
      @services ||= ::PackmanNova::Sync::Services.from_config(config:, logger:, workdir:)
    end

    def subprocess
      @subprocess ||= ::PackmanNova::Utils::Subprocess.new(logger:)
    end

    def workdir
      @workdir ||= config.workdir
    end
  end
end
