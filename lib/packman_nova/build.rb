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
require 'packman_nova/pbuild/baselibs'
require 'packman_nova/pbuild/record_writer'
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
      release ||= allocator.peek
      commands(selection, tuning, release).each { |command| out.puts(::Shellwords.join(executor.command(command.argv))) }
      0
    end

    def build(selection, tuning, release)
      project_dir.validate!([*selection[:rebuild_packages], *selection[:single]])
      image_id = environment.image.ensure!
      run, release = allocator.allocate(release)
      started_at = clock.call
      passes = run_passes(commands(selection, tuning, release), run)
      report(record_writer.call(*passes, run: run, release: release, image_id: image_id, started_at: started_at), passes)
    end

    def commands(selection, tuning, release)
      main = pbuild_command(selection, tuning, release)
      environment.baselibs? ? [main, pbuild_command(selection, tuning, release, baselibs: true)] : [main]
    end

    def run_passes(commands, run)
      logger.info("run #{run}, release #{commands.first.release}#{', rebuilding everything' if commands.first.rebuild?}")
      project_dir.prepare!
      commands.map { |command| run_pass(command) }
    end

    def run_pass(command)
      logger.info("pbuild --arch #{command.arch}#{' --baselibs' if command.baselibs?}")
      ::PackmanNova::Pbuild::RecordWriter::Pass.new(command: command, status: executor.run(command.argv, timeout_sec: config.pbuild.timeout_sec))
    end

    def report(record, passes)
      out.print(::PackmanNova::Pbuild::Summary.new(record: record).to_s)
      return 1 unless ::PackmanNova::Pbuild::Summary.failed_packages(record).empty?

      check_exits!(passes)
      sync_state.clear_rebuild_all! if passes.first.command.rebuild?
      0
    end

    def check_exits!(passes)
      failed = passes.reject { |pass| pass.status.success? }
      return if failed.empty?

      raise ::PackmanNova::BuildError.new(failed.map { |pass| "pbuild --arch #{pass.command.arch} exited with #{pass.status.exitstatus.inspect}" }.join('; '), failed_packages: [])
    end

    def record_writer
      ::PackmanNova::Pbuild::RecordWriter.new(environment: environment, build_record: build_record, allocator: allocator, logger: logger, clock: clock)
    end

    def pbuild_command(selection, tuning, release, baselibs: false)
      implicit = selection[:rebuild_packages].empty? && selection[:single].nil? && sync_state.rebuild_all_required?
      environment.command(release: release, baselibs: baselibs, **tuning, **selection, rebuild: selection[:rebuild] || implicit)
    end
  end
end
