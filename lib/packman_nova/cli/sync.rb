# frozen_string_literal: true

module PackmanNova
  class Cli
    class Sync < ::PackmanNova::Cli::Command
      class << self
        def summary
          'materialize package sources into the workdir project dir'
        end

        def options(parser, options)
          parser.on('--check', 'only report drift; exit 2 when anything changed') { options[:check] = true }
          parser.on('--package NAME', 'limit to this package (repeatable)') { |name| (options[:packages] ||= []) << name }
          parser.on('--update-checksums', 'fill sha256/size in package.yml from the first download') { options[:update_checksums] = true }
          parser.on('--[no-]prjconf', 'refresh the base prjconf (default: yes)') { |value| options[:prjconf] = value }
        end
      end

      DRIFT_EXIT_CODE = 2

      def call
        report = sync.call(
          packages: options[:packages], check_only: check?, update_checksums: options.fetch(:update_checksums, false),
          prjconf: options.fetch(:prjconf, true)
        )
        print_report(report)
        exit_code(report)
      end

      private

      def check?
        options.fetch(:check, false)
      end

      def sync
        ::PackmanNova::Sync.new(config:, logger:)
      end

      def print_report(report)
        report.lines.each { |line| logger.info(line) }
      end

      def exit_code(report)
        return 1 if report.failed?
        return DRIFT_EXIT_CODE if check? && report.drift?

        0
      end
    end
  end
end
