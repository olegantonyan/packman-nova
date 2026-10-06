# frozen_string_literal: true

module PackmanNova
  class Cli
    class Update < ::PackmanNova::Cli::Command
      OUTDATED_EXIT_CODE = 2
      NAME_WIDTH = 30
      LABELS = {
        ok: ['ok', :green], outdated: ['new', :yellow], updated: ['done', :green], skipped: ['skip', :dim], failed: ['fail', :red]
      }.freeze

      class << self
        def summary
          'probe upstream for newer native package versions and update them'
        end

        def options(parser, options)
          parser.on('--check', 'only report; exit 2 when a newer version exists') { options[:check] = true }
          parser.on('--package NAME', 'limit to this package (repeatable)') { |name| (options[:packages] ||= []) << name }
          parser.on('--version V', 'update one package to this version (commit or ref for branch watches)') { |value| options[:version] = value }
        end
      end

      def call
        raise ::PackmanNova::UpstreamError, '--check and --version are exclusive' if check? && options[:version]

        results = run_upstream
        results.each { |result| report(result) }
        print_next_step(results)
        exit_code(results)
      end

      private

      def check?
        options.fetch(:check, false)
      end

      def run_upstream
        upstream = ::PackmanNova::Upstream.new(config:, logger:)
        check? ? upstream.check(packages: options[:packages]) : upstream.update(packages: options[:packages], version: options[:version])
      end

      def report(result)
        text, color = LABELS.fetch(result.state)
        label = ::PackmanNova::Utils::Color.enabled?(out) ? ::PackmanNova::Utils::Color.paint(text.ljust(4), color) : text.ljust(4)
        out.puts("#{label}  #{result.name.ljust(NAME_WIDTH)} #{result.text}")
      end

      def print_next_step(results)
        names = results.select { |result| result.state == :updated }.map(&:name)
        return if names.empty?

        out.puts("next: review git diff packages/, then packman-nova build #{names.map { |name| "--package #{name}" }.join(' ')}")
      end

      def exit_code(results)
        return 1 if results.any? { |result| result.state == :failed }
        return OUTDATED_EXIT_CODE if results.any? { |result| result.state == :outdated }

        0
      end
    end
  end
end
