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
        release_for(run_counter.peek(floor:))
      end

      def allocate(release = nil)
        return [explicit_run(release), release] if release

        @snapshot = run_counter.snapshot
        run = run_counter.next!(floor:) { |next_run| release_for(next_run) }
        [run, release_for(run)]
      end

      def give_back!
        return false unless defined?(@snapshot)

        run_counter.restore!(@snapshot)
        true
      end

      def floor
        [published_run, built_run].max
      end

      def release_for(run)
        ::PackmanNova::Release.new(template: config.release.template, suse_version: config.distro.suse_version, run:).to_s
      end

      private

      attr_reader :config, :environment, :clock

      def explicit_run(release)
        ::PackmanNova::Release.parse_run(release, template: config.release.template) || ::PackmanNova::Release.parse_run(release) || run_counter.current
      end

      def published_run
        environment.repo_state_files.map { |path| run_in(path) }.max || 0
      end

      def built_run
        results_dir = environment.project_dir.results_dir
        return 0 unless ::File.directory?(results_dir)

        ::Dir.glob('*/*.rpm', base: results_dir).filter_map { |path| ::PackmanNova::Release.parse_run(::File.basename(path), template: config.release.template) }.max || 0
      end

      def run_in(path)
        data = ::PackmanNova::Utils::JsonFile.read(path, default: {})
        run = data.is_a?(::Hash) ? data['run'] : nil
        run.is_a?(::Integer) ? run : 0
      rescue ::PackmanNova::Error
        0
      end

      def run_counter
        @run_counter ||= ::PackmanNova::State::RunCounter.new(workdir: environment.workdir, clock:)
      end
    end
  end
end
