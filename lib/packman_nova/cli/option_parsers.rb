# frozen_string_literal: true

require 'optparse'

module PackmanNova
  class Cli
    class OptionParsers
      PROGRAM_NAME = 'packman-nova'

      def initialize(global:, commands:)
        @global = global
        @commands = commands
      end

      def global_parser
        @global_parser ||= ::OptionParser.new do |parser|
          parser.banner = "Usage: #{PROGRAM_NAME} [global options] <command> [command options]"
          define_global_options(parser)
          parser.on('--version', 'print the version') { global[:version] = true }
          parser.on('-h', '--help', 'show this help') { global[:help] = true }
          describe_commands(parser)
        end
      end

      def command_parser(name, command_class, options)
        ::OptionParser.new do |parser|
          parser.banner = "Usage: #{PROGRAM_NAME} [global options] #{name} #{command_class.usage}"
          parser.separator(command_class.summary)
          parser.separator('')
          command_class.options(parser, options)
          parser.on('-h', '--help', 'show this help') { options[:help] = true }
          parser.separator('')
          parser.separator('Global options:')
          define_global_options(parser)
        end
      end

      private

      attr_reader :global, :commands

      def define_global_options(parser)
        define_location_options(parser)
        define_output_options(parser)
      end

      def define_location_options(parser)
        parser.on('-c', '--config FILE', 'config file merged over the defaults (default: ./packman-nova.yml)') { |value| global[:config] = value }
        parser.on('-w', '--workdir DIR', 'workdir (overrides PACKMAN_NOVA_WORKDIR)') { |value| global[:workdir] = value }
        parser.on('--offline', 'no network, caches only') { global[:offline] = true }
      end

      def define_output_options(parser)
        parser.on('-v', '--verbose', 'debug output and backtraces') { global[:verbose] = true }
        parser.on('-q', '--quiet', 'warnings and errors only') { global[:quiet] = true }
        parser.on('--[no-]log-file', 'write logs/<timestamp>-<command>.log in the workdir (default: yes)') { |value| global[:log_file] = value }
      end

      def describe_commands(parser)
        parser.separator('')
        parser.separator('Commands:')
        commands.each { |name, klass| parser.separator(format('    %-8<name>s %<summary>s', name: name, summary: klass.summary)) }
        parser.separator('')
        parser.separator("See '#{PROGRAM_NAME} <command> --help' for command options.")
      end
    end
  end
end
