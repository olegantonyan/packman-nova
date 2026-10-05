# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class RecordWriter
      Pass = ::Data.define(:command, :status)

      def initialize(environment:, build_record:, allocator:, logger:, clock:)
        @environment = environment
        @build_record = build_record
        @allocator = allocator
        @logger = logger
        @clock = clock
      end

      def call(main, baselibs_pass = nil, **fields)
        parser = collect_codes(main.command)
        baselibs = baselibs_pass && baselibs_for(baselibs_pass.command)
        record = compose(main, parser, baselibs, fields)
        logger.info("build record #{build_record.write(record)}")
        record
      end

      private

      attr_reader :environment, :build_record, :allocator, :logger, :clock

      def compose(main, parser, baselibs, fields)
        results = ::PackmanNova::Pbuild::Results.scan(environment.project_dir.results_dir)
        build_record.compose(
          results: results, codes: parser.codes, details: parser.details, baselibs: baselibs&.entries || {},
          **fields, **main_fields(main), built: built_keys(results, baselibs, **fields)
        )
      end

      def baselibs_for(command)
        parser = collect_codes(command)
        ::PackmanNova::Pbuild::Baselibs.new(
          results: ::PackmanNova::Pbuild::Results.scan(environment.baselibs_results_dir), codes: parser.codes, details: parser.details,
          arch: command.arch, export_arch: environment.project_dir.arch
        )
      end

      def built_keys(results, baselibs, run:, started_at:, **)
        built = results.select { |_key, result| result.built_since?(started_at) }.keys | (baselibs&.built_since(started_at) || [])
        logger.info("nothing was built, run #{run} stays free") if built.empty? && allocator.give_back!
        built.sort
      end

      def main_fields(main)
        {
          finished_at: clock.call, arch: environment.project_dir.arch, tumbleweed_snapshot: environment.sync_state.tumbleweed_snapshot,
          pbuild_argv: main.command.argv, pbuild_exit: main.status.exitstatus
        }
      end

      def collect_codes(command)
        ::PackmanNova::Pbuild::ResultParser.parse(environment.executor.capture(command.result_argv(details: true)))
      rescue ::PackmanNova::SubprocessError => e
        logger.warn("pbuild result query failed, using result files only: #{e.message.lines.first&.strip}")
        ::PackmanNova::Pbuild::ResultParser.parse('')
      end
    end
  end
end
