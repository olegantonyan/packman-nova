# frozen_string_literal: true

require 'time'

module PackmanNova
  class Sync
    class Run
      PACKAGE_ERRORS = [::PackmanNova::Error, ::SystemCallError].freeze

      def initialize(config:, logger:, workdir:, services:, manifests:, options:)
        @config = config
        @logger = logger
        @workdir = workdir
        @services = services
        @manifests = manifests
        @options = options
        @report = ::PackmanNova::Sync::Report.new(check_only: check_only?)
      end

      def call(previous)
        prjconf = sync_prjconf(previous)
        snapshot = sync_snapshot(previous)
        manifests.select(&:enabled?).each { |manifest| sync_package(manifest, previous) }
        prune
        finish(previous, prjconf, snapshot)
      end

      private

      attr_reader :config, :logger, :workdir, :services, :manifests, :options, :report

      def finish(previous, prjconf, snapshot)
        next_state = ::PackmanNova::Sync::NextState.new(previous: previous, report: report, enabled_names: enabled_names, filtered: !options[:packages].nil?)
        report.rebuild_all_required = next_state.rebuild_all_required?(prjconf.local_md5)
        [report, next_state.call(prjconf: prjconf, snapshot: snapshot)]
      end

      def check_only?
        options.fetch(:check_only)
      end

      def sync_prjconf(previous)
        result = prjconf.call(refresh: options.fetch(:prjconf), write: !check_only?)
        report.track('Factory prjconf md5', previous: previous['factory_prjconf_md5'], current: result.factory_md5)
        report.track('local _config md5', previous: previous['local_config_md5'], current: result.local_md5)
        result
      end

      def prjconf
        ::PackmanNova::Sync::Prjconf.new(config: config, workdir: workdir, downloader: services.downloader, logger: logger)
      end

      def sync_snapshot(previous)
        snapshot = ::PackmanNova::Sync::Snapshot.new(url: config.distro.snapshot_url, downloader: services.downloader, logger: logger)
        current = snapshot.call(previous: previous['tumbleweed_snapshot'])
        report.track('Tumbleweed snapshot', previous: previous['tumbleweed_snapshot'], current: current)
        current
      end

      def sync_package(manifest, previous)
        started = monotonic
        outcome = materialize(manifest, previous.fetch('packages')[manifest.name])
        report.add(outcome)
        log_outcome(outcome, monotonic - started)
      rescue *PACKAGE_ERRORS => e
        record_failure(manifest, e)
      end

      def materialize(manifest, previous_record)
        outcome = materializer(manifest).call(previous: previous_record, check_only: check_only?)
        update_checksums(manifest, outcome)
        outcome
      end

      def record_failure(manifest, error)
        logger.error("#{manifest.name}: #{error.class}: #{error.message}")
        report.fail(manifest.name, error.message.lines.first.to_s.strip)
      end

      def monotonic
        ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      end

      def materializer(manifest)
        arguments = { manifest: manifest, services: services, workdir: workdir, logger: logger }
        return ::PackmanNova::Sync::ObsLinkMaterializer.new(**arguments) if manifest.obs_link?

        ::PackmanNova::Sync::NativeMaterializer.new(config: config, **arguments)
      end

      def update_checksums(manifest, outcome)
        return unless options.fetch(:update_checksums) && !check_only?

        path = ::File.join(manifest.dir, ::PackmanNova::Manifest::FILE_NAME)
        logger.info("#{manifest.name}: filled sha256/size in #{path}") if ::PackmanNova::Sync::ChecksumUpdater.new(manifest_path: path).call(outcome.checksums)
      end

      def log_outcome(outcome, seconds)
        suffix = outcome.changed? ? " (#{outcome.detail})" : ''
        logger.info(format('%<name>s: %<status>s%<suffix>s in %<seconds>.1fs', name: outcome.name, status: outcome.status, suffix: suffix, seconds: seconds))
      end

      def prune
        stale = ::PackmanNova::Sync::StaleDirs.new(project_dir: workdir.project_dir).call(keep: enabled_names, only: options[:packages])
        stale.each do |name|
          report.remove(name)
          remove_dir(name) unless check_only?
        end
      end

      def remove_dir(name)
        logger.info("#{name}: removing #{workdir.package_dir(name)}")
        ::PackmanNova::Sync::PackageDir.new(path: workdir.package_dir(name)).remove
      end

      def enabled_names
        manifests.select(&:enabled?).map(&:name)
      end
    end
  end
end
