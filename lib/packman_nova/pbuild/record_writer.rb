# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class RecordWriter
      Pass = ::Data.define(:command, :status)
      SKIPPED_BASELIBS_CODES = %w[excluded disabled].freeze

      def initialize(environment:, build_record:, allocator:, logger:, clock:)
        @environment = environment
        @build_record = build_record
        @allocator = allocator
        @logger = logger
        @clock = clock
      end

      def call(main, baselibs_pass = nil, **fields)
        record = compose(main, collect_codes(main.command), baselibs_pass, fields)
        logger.info("build record #{build_record.write(record)}")
        record
      end

      private

      attr_reader :environment, :build_record, :allocator, :logger, :clock

      def compose(main, parser, baselibs_pass, fields)
        results = ::PackmanNova::Pbuild::Results.scan(environment.project_dir.results_dir)
        baselibs_results = baselibs_pass ? ::PackmanNova::Pbuild::Results.scan(environment.baselibs_results_dir) : {}
        build_record.compose(
          results:, codes: parser.codes, details: parser.details, baselibs: baselibs_pass ? baselibs_entries(baselibs_pass.command, baselibs_results) : {},
          **fields, **main_fields(main), built: built_keys([results, baselibs_results], **fields)
        )
      end

      def baselibs_entries(command, results)
        parser = collect_codes(command)
        entries = (results.keys | parser.codes.keys).sort.to_h { |key| [key, baselibs_entry(command.arch, results[key], parser, key)] }
        entries.reject { |_key, entry| SKIPPED_BASELIBS_CODES.include?(entry['code']) }
      end

      def baselibs_entry(arch, result, parser, key)
        { 'arch' => arch, 'code' => parser.codes[key] || result&.status || 'unknown', 'rpms' => exported_rpms(result), 'details' => parser.details[key] }
      end

      def exported_rpms(result)
        result ? result.rpm_files.select { |file| file.end_with?(".#{environment.project_dir.arch}.rpm") } : []
      end

      def built_keys(scans, run:, started_at:, **)
        built = scans.flat_map { |results| results.select { |_key, result| result.built_since?(started_at) }.keys }.uniq
        logger.info("nothing was built, run #{run} stays free") if built.empty? && allocator.give_back!
        built.sort
      end

      def main_fields(main)
        {
          finished_at: clock.call, arch: environment.project_dir.arch, distro_snapshot: environment.sync_state.snapshot,
          pbuild_argv: main.command.argv, pbuild_exit: main.status.exitstatus
        }
      end

      def collect_codes(command)
        ::PackmanNova::Pbuild::ResultParser.parse(environment.executor.capture(command.result_argv))
      rescue ::PackmanNova::SubprocessError => e
        logger.warn("pbuild result query failed, using result files only: #{e.message.lines.first&.strip}")
        ::PackmanNova::Pbuild::ResultParser.parse('')
      end
    end
  end
end
