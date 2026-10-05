# frozen_string_literal: true

require 'time'

module PackmanNova
  class Sync
    class Run
      PACKAGE_ERRORS = [::PackmanNova::Error, ::SystemCallError].freeze
      SNAPSHOT_DATE = /\b(\d{8})\b/

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
        report.rebuild_all_required = rebuild_all_required?(previous, prjconf.local_md5)
        next_state = {
          'schema' => ::PackmanNova::State::Schemas::VERSION, 'synced_at' => ::Time.now.utc.iso8601,
          'distro_snapshot' => snapshot, 'base_prjconf_md5' => prjconf.factory_md5, 'local_config_md5' => prjconf.local_md5,
          'rebuild_all_required' => report.rebuild_all_required, 'packages' => next_packages(previous)
        }
        [report, next_state]
      end

      def rebuild_all_required?(previous, local_md5)
        before = previous['local_config_md5']
        (!before.nil? && before != local_md5) || previous.fetch('rebuild_all_required', false)
      end

      def next_packages(previous)
        kept = previous.fetch('packages').except(*report.removed)
        kept = kept.slice(*enabled_names) unless options[:packages]
        kept.merge(outcome_records).sort.to_h
      end

      def outcome_records
        report.outcomes.to_h { |outcome| [outcome.name, outcome.record] }
      end

      def check_only?
        options.fetch(:check_only)
      end

      def sync_prjconf(previous)
        result = prjconf.call(refresh: options.fetch(:prjconf), write: !check_only?)
        report.track('base prjconf md5', previous: previous['base_prjconf_md5'], current: result.factory_md5)
        report.track('local _config md5', previous: previous['local_config_md5'], current: result.local_md5)
        result
      end

      def prjconf
        ::PackmanNova::Sync::Prjconf.new(config:, workdir:, downloader: services.downloader, logger:)
      end

      def sync_snapshot(previous)
        current = fetch_snapshot || previous['distro_snapshot']
        report.track('distro snapshot', previous: previous['distro_snapshot'], current:)
        current
      end

      def fetch_snapshot
        return if services.downloader.offline?

        body = services.downloader.get(config.distro.snapshot_url)
        body[SNAPSHOT_DATE, 1] || body.lines.first&.strip
      rescue ::PackmanNova::DownloadError => e
        logger.warn("distro snapshot: #{e.message}")
        nil
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
        arguments = { manifest:, services:, workdir:, logger: }
        return ::PackmanNova::Sync::ObsLinkMaterializer.new(**arguments) if manifest.obs_link?

        ::PackmanNova::Sync::NativeMaterializer.new(config:, **arguments)
      end

      def update_checksums(manifest, outcome)
        return unless options.fetch(:update_checksums) && !check_only?

        path = ::File.join(manifest.dir, ::PackmanNova::Manifest::FILE_NAME)
        logger.info("#{manifest.name}: filled sha256/size in #{path}") if ::PackmanNova::Sync::ChecksumUpdater.new(manifest_path: path).call(outcome.checksums)
      end

      def log_outcome(outcome, seconds)
        suffix = outcome.changed? ? " (#{outcome.detail})" : ''
        logger.info(format('%<name>s: %<status>s%<suffix>s in %<seconds>.1fs', name: outcome.name, status: outcome.status, suffix:, seconds:))
      end

      def prune
        stale_dirs.each do |name|
          report.remove(name)
          remove_dir(name) unless check_only?
        end
      end

      def stale_dirs
        candidates = workdir.package_names
        candidates &= options[:packages] if options[:packages]
        candidates - enabled_names
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
