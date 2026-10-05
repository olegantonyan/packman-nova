# frozen_string_literal: true

require 'fileutils'
require 'optparse'

module PackmanNova
  class Cli
    PROGRAM_NAME = 'packman-nova'
    INTERRUPTED_EXIT_CODE = 130
    COMMANDS = {
      'check' => ::PackmanNova::Cli::Check,
      'sync' => ::PackmanNova::Cli::Sync,
      'build' => ::PackmanNova::Cli::Build,
      'publish' => ::PackmanNova::Cli::Publish,
      'status' => ::PackmanNova::Cli::Status,
      'site' => ::PackmanNova::Cli::Site,
      'gpg' => ::PackmanNova::Cli::Gpg,
      'image' => ::PackmanNova::Cli::Image,
      'clean' => ::PackmanNova::Cli::Clean,
      'state' => ::PackmanNova::Cli::State,
      'run' => ::PackmanNova::Cli::Run
    }.freeze

    def initialize(argv:, out: $stdout, err: $stderr)
      @argv = argv.dup
      @out = out
      @err = err
      @global = { log_file: true }
    end

    def call
      run
    rescue ::StandardError, ::Interrupt => e
      exit_code_for(e)
    ensure
      log_file&.close
    end

    private

    attr_reader :argv, :out, :err, :global, :logger, :log_file

    def verbose?
      global.fetch(:verbose, false)
    end

    def run
      global_parser.order!(argv)
      return print_and_succeed(::PackmanNova::VERSION) if global[:version]
      return print_and_succeed(global_parser) if global[:help]

      dispatch(argv.shift)
    end

    def dispatch(name)
      command_class = COMMANDS.fetch(name) { raise ::OptionParser::InvalidArgument, name ? "unknown command '#{name}'" : 'no command given' }
      options = {}
      parser = command_parser(name, command_class, options)
      parser.parse!(argv)
      return print_and_succeed(parser) if options[:help]

      config, config_error = load_config(command_class)
      @logger = build_logger(name, command_class, config)
      command_class.new(config:, logger:, options:, args: argv, out:, config_error:).call
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
      COMMANDS.each { |name, klass| parser.separator(format('    %-8<name>s %<summary>s', name:, summary: klass.summary)) }
      parser.separator('')
      parser.separator("See '#{PROGRAM_NAME} <command> --help' for command options.")
    end

    def load_config(command_class)
      overrides = { workdir: global[:workdir] && ::File.expand_path(global[:workdir]), offline: global[:offline] }.compact
      [::PackmanNova::Config.load(path: global[:config], overrides:), nil]
    rescue ::PackmanNova::ConfigError => e
      raise unless command_class.tolerates_config_error?

      [nil, e]
    end

    def build_logger(name, command_class, config)
      logger = ::PackmanNova::Logging::Logger.new(outputs: [out], level: log_level)
      return logger unless config

      logger = logger.add_filters(*config.secrets)
      log_config_sources(logger, config)
      command_class.log_file? && global[:log_file] ? logger.add_outputs(open_log_file(config.workdir, name)) : logger
    end

    def log_config_sources(logger, config)
      logger.debug("config files: #{config.files.join(', ')}")
      logger.debug("env vars used: #{config.env_vars_used.join(', ')}; unset: #{config.env_vars_missing.join(', ')}")
    end

    def open_log_file(workdir, name)
      path = workdir.log_file(name)
      ::FileUtils.mkdir_p(::File.dirname(path))
      @log_file = ::File.open(path, 'a')
    end

    def log_level
      return ::Logger::DEBUG if verbose?
      return ::Logger::WARN if global[:quiet]

      ::Logger::INFO
    end

    def exit_code_for(error)
      case error
      when ::Interrupt
        err.puts('interrupted')
        return INTERRUPTED_EXIT_CODE
      when ::OptionParser::ParseError
        err.puts("#{error.message}; see '#{PROGRAM_NAME} --help'")
      else
        report_error(error)
      end
      1
    end

    def report_error(error)
      lines = ["#{error.class}: #{error.message}"]
      lines << error.backtrace.to_a.join("\n") if verbose?
      lines.each { |line| logger ? logger.error(line) : err.puts(line) }
    end

    def print_and_succeed(text)
      out.puts(text)
      0
    end
  end
end
