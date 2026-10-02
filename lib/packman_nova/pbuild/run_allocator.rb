# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class RunAllocator
      def initialize(config:, environment:, clock: -> { ::Time.now.utc })
        @config = config
        @environment = environment
        @clock = clock
      end

      def peek
        release_for(run_counter.peek(floor: floor))
      end

      def allocate(release = nil)
        return [explicit_run(release), release] if release

        @snapshot = run_counter.snapshot
        run = run_counter.next!(floor: floor) { |next_run| release_for(next_run) }
        [run, release_for(run)]
      end

      def give_back!
        return false unless defined?(@snapshot)

        run_counter.restore!(@snapshot)
        true
      end

      def floor
        ::PackmanNova::Pbuild::RunFloor.new(
          repo_state_files: environment.repo_state_files, results_dir: environment.project_dir.results_dir, template: config.release.template
        ).call
      end

      def release_for(run)
        ::PackmanNova::Release.new(template: config.release.template, suse_version: config.distro.suse_version, run: run).to_s
      end

      private

      attr_reader :config, :environment, :clock

      def explicit_run(release)
        ::PackmanNova::Release.parse_run(release, template: config.release.template) || ::PackmanNova::Release.parse_run(release) || run_counter.current
      end

      def run_counter
        @run_counter ||= ::PackmanNova::State::RunCounter.new(workdir: environment.workdir, clock: clock)
      end
    end
  end
end
