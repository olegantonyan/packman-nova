# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class RunFloor
      def initialize(repo_state_files:, results_dir:, template: nil)
        @repo_state_files = repo_state_files
        @results_dir = results_dir
        @template = template
      end

      def call
        [published_run, built_run].max
      end

      def published_run
        repo_state_files.map { |path| run_in(path) }.max || 0
      end

      def built_run
        return 0 unless ::File.directory?(results_dir)

        ::Dir.glob('*/*.rpm', base: results_dir).filter_map { |path| ::PackmanNova::Release.parse_run(::File.basename(path), template: template) }.max || 0
      end

      private

      attr_reader :repo_state_files, :results_dir, :template

      def run_in(path)
        data = ::PackmanNova::Utils::JsonFile.read(path, default: {})
        run = data.is_a?(::Hash) ? data['run'] : nil
        run.is_a?(::Integer) ? run : 0
      rescue ::PackmanNova::Error
        0
      end
    end
  end
end
