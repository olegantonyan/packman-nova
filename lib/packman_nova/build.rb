# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require 'time'

require 'packman_nova/release'
require 'packman_nova/state/run_counter'
require 'packman_nova/state/build_record'
require 'packman_nova/pbuild/project_dir'
require 'packman_nova/pbuild/command'
require 'packman_nova/pbuild/result_parser'
require 'packman_nova/pbuild/reason'
require 'packman_nova/pbuild/job_history'
require 'packman_nova/pbuild/package_result'
require 'packman_nova/pbuild/results'
require 'packman_nova/pbuild/executor'
require 'packman_nova/pbuild/run_floor'
require 'packman_nova/pbuild/run_allocator'
require 'packman_nova/pbuild/table'
require 'packman_nova/pbuild/summary'
require 'packman_nova/pbuild/sync_state'
require 'packman_nova/pbuild/sync_runner'
require 'packman_nova/pbuild/environment'

module PackmanNova
  class Build
    def initialize(config:, logger:, out: $stdout, environment: nil, sync: nil, clock: -> { ::Time.now.utc })
      @config = config
      @logger = logger
      @out = out
      @environment = environment || ::PackmanNova::Pbuild::Environment.new(config: config, logger: logger)
      @sync = sync
      @clock = clock
    end

    def call(packages: [], rebuild: false, single: nil, buildjobs: nil, jobs: nil, checks: nil, debuginfo: nil, no_repo_refresh: nil,
             release: nil, sync: true, dry_run: false)
      selection = { rebuild_packages: packages, rebuild: rebuild, single: single }
      tuning = { buildjobs: buildjobs, jobs: jobs, checks: checks, debuginfo: debuginfo, repo_refresh: no_repo_refresh.nil? ? nil : !no_repo_refresh }.compact
      return print_dry_run(selection, tuning, release) if dry_run

      ::PackmanNova::Pbuild::SyncRunner.new(config: config, logger: logger, sync: @sync).call if sync
      workdir.with_lock { build(selection, tuning, release) }
    end

    private

    attr_reader :config, :logger, :out, :environment, :clock

    def workdir = environment.workdir
    def project_dir = environment.project_dir
    def executor = environment.executor

    def sync_state
      @sync_state ||= environment.sync_state
    end

    def build_record
      @build_record ||= ::PackmanNova::State::BuildRecord.new(workdir: workdir)
    end

    def allocator
      @allocator ||= ::PackmanNova::Pbuild::RunAllocator.new(config: config, environment: environment, clock: clock)
    end

    def print_dry_run(selection, tuning, release)
      command = pbuild_command(selection, tuning, release || allocator.peek)
      out.puts(::Shellwords.join(executor.command(command.argv)))
      0
    end

    def build(selection, tuning, release)
      project_dir.validate!([*selection[:rebuild_packages], *selection[:single]])
      image_id = environment.image.ensure!
      run, release = allocator.allocate(release)
      command = pbuild_command(selection, tuning, release)
      started_at = clock.call
      status = run_pbuild(command, run)
      report(write_record(command, status, run: run, release: release, image_id: image_id, started_at: started_at), status, command)
    end

    def run_pbuild(command, run)
      logger.info("run #{run}, release #{command.release}#{', rebuilding everything' if command.rebuild?}")
      project_dir.prepare!
      executor.run(command.argv, timeout_sec: config.pbuild.timeout_sec)
    end

    def report(record, status, command)
      out.print(::PackmanNova::Pbuild::Summary.new(record: record).to_s)
      failed = ::PackmanNova::Pbuild::Summary.failed_packages(record)
      return 1 unless failed.empty?
      raise ::PackmanNova::BuildError.new("pbuild exited with #{status.exitstatus.inspect}", failed_packages: []) unless status.success?

      sync_state.clear_rebuild_all! if command.rebuild?
      0
    end

    def write_record(command, status, **fields)
      results = ::PackmanNova::Pbuild::Results.scan(project_dir.results_dir)
      built = built_keys(results, **fields)
      parser = collect_codes(command)
      record = build_record.compose(results: results, codes: parser.codes, details: parser.details, **fields, **record_fields(command, status), built: built)
      logger.info("build record #{build_record.write(record)}")
      record
    end

    def built_keys(results, run:, started_at:, **)
      built = results.select { |_key, result| result.built_since?(started_at) }.keys
      logger.info("nothing was built, run #{run} stays free") if built.empty? && allocator.give_back!
      built
    end

    def record_fields(command, status)
      {
        finished_at: clock.call, arch: project_dir.arch, tumbleweed_snapshot: sync_state.tumbleweed_snapshot,
        pbuild_argv: command.argv, pbuild_exit: status.exitstatus
      }
    end

    def collect_codes(command)
      ::PackmanNova::Pbuild::ResultParser.parse(executor.capture(command.result_argv(details: true)))
    rescue ::PackmanNova::SubprocessError => e
      logger.warn("pbuild result query failed, using result files only: #{e.message.lines.first&.strip}")
      ::PackmanNova::Pbuild::ResultParser.parse('')
    end

    def pbuild_command(selection, tuning, release)
      implicit = selection[:rebuild_packages].empty? && selection[:single].nil? && sync_state.rebuild_all_required?
      environment.command(release: release, **tuning, **selection, rebuild: selection[:rebuild] || implicit)
    end
  end
end
