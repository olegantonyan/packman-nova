# frozen_string_literal: true

module PackmanNova
  class Sync
    class StaleDirs
      def initialize(project_dir:)
        @project_dir = project_dir
      end

      def call(keep:, only: nil)
        return [] unless ::File.directory?(project_dir)

        candidates = ::Dir.children(project_dir).sort.reject { |entry| entry.start_with?('_', '.') }
        candidates &= only if only
        candidates.reject { |entry| keep.include?(entry) }.select { |entry| ::File.directory?(::File.join(project_dir, entry)) }
      end

      private

      attr_reader :project_dir
    end
  end
end
