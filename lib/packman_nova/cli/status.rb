# frozen_string_literal: true

require 'json'

module PackmanNova
  class Cli
    class Status < ::PackmanNova::Cli::Command
      HEADERS = %w[package kind srcmd5 code release rpms built_at published].freeze
      SHORT_MD5 = 8
      RPM_RELEASE = /-([^-]+)\.[^.]+\.rpm\z/

      class << self
        def summary
          'show per-package sync, build and publish status'
        end

        def options(parser, options)
          parser.on('--json', 'print JSON') { options[:json] = true }
          parser.on('--live', 'ask pbuild for result codes inside the container') { options[:live] = true }
        end
      end

      def call
        rows = package_names.map { |name| row(name) }
        options[:json] ? out.puts(::JSON.pretty_generate(document(rows))) : print_table(rows)
        0
      end

      private

      def environment
        @environment ||= ::PackmanNova::Pbuild::Environment.new(config:, logger:)
      end

      def last_build
        @last_build ||= ::PackmanNova::State::BuildRecord.new(workdir: environment.workdir).last || {}
      end

      def synced
        @synced ||= environment.sync_state.packages
      end

      def published
        @published ||= environment.repo_state_files.filter_map { |path| read_json(path) }.first&.fetch('packages', nil) || {}
      end

      def live_codes
        @live_codes ||= options[:live] ? query_live_codes : {}
      end

      def query_live_codes
        text = environment.executor.capture(environment.command(release: last_build.fetch('release', '')).result_argv)
        ::PackmanNova::Pbuild::ResultParser.parse(text).codes
      end

      def package_names
        (synced.keys | last_build.fetch('packages', {}).keys | live_codes.keys).sort
      end

      def row(name)
        base = ::PackmanNova::Manifest.base_name(name)
        { 'package' => name, **sync_columns(base), **build_columns(name), 'published' => published.dig(base, 'release') }
      end

      def sync_columns(base)
        { 'kind' => synced.dig(base, 'kind'), 'srcmd5' => synced.dig(base, 'srcmd5')&.slice(0, SHORT_MD5) }
      end

      def build_columns(name)
        built = last_build.fetch('packages', {}).fetch(name, {})
        rpms = built.fetch('rpms', [])
        {
          'code' => live_codes.fetch(name) { built['code'] }, 'release' => release_of([built['srpm'], *rpms].compact.first),
          'rpms' => rpms.size, 'built_at' => built['built_at']
        }
      end

      def release_of(file)
        file && RPM_RELEASE.match(file)&.[](1)
      end

      def document(rows)
        { 'run' => last_build['run'], 'release' => last_build['release'], 'finished_at' => last_build['finished_at'], 'packages' => rows }
      end

      def print_table(rows)
        out.puts(headline)
        out.print(::PackmanNova::Pbuild::Table.new(headers: HEADERS, rows: rows.map { |row| row.values_at(*HEADERS) }).to_s) unless rows.empty?
      end

      def headline
        return 'no build recorded yet' if last_build.empty?

        "last build: run #{last_build['run']}, release #{last_build['release']}, finished #{last_build['finished_at']}"
      end

      def read_json(path)
        ::PackmanNova::Utils::JsonFile.read(path)
      rescue ::PackmanNova::Error
        nil
      end
    end
  end
end
