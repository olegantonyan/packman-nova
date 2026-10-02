# frozen_string_literal: true

require 'packman_nova/pipeline/result'

module PackmanNova
  class Pipeline
    def initialize(config:, logger:, out: $stdout, sync: nil, build: nil, publisher: nil, build_record: nil)
      @config = config
      @logger = logger
      @out = out
      @sync = sync
      @build = build
      @publisher = publisher
      @build_record = build_record
    end

    def call(publish: true, provider: nil)
      sync_report = run_sync
      build.call(sync: false)
      record = build_record.last || {}
      diff, error = publish ? run_publish(provider) : [nil, nil]
      ::PackmanNova::Pipeline::Result.new(
        sync_failed: sync_report.failed.keys, record: record, failed_packages: ::PackmanNova::Pbuild::Summary.failed_packages(record),
        published: publish, diff: diff, publish_error: error
      )
    end

    private

    attr_reader :config, :logger, :out

    def run_sync
      report = sync.call(packages: nil, check_only: false, update_checksums: false)
      report.lines.each { |line| logger.info(line) }
      logger.warn("sync failed for #{report.failed.keys.join(', ')}; building their previous sources") if report.failed?
      report
    end

    def run_publish(provider)
      [publisher.call(provider: provider), nil]
    rescue ::StandardError => e
      logger.error("publish failed: #{e.class}: #{e.message}")
      [nil, e]
    end

    def sync
      @sync ||= ::PackmanNova::Sync.new(config: config, logger: logger)
    end

    def build
      @build ||= ::PackmanNova::Build.new(config: config, logger: logger, out: out)
    end

    def publisher
      @publisher ||= ::PackmanNova::Publish.new(config: config, logger: logger, out: out)
    end

    def build_record
      @build_record ||= ::PackmanNova::State::BuildRecord.new(workdir: config.workdir)
    end
  end
end
