# frozen_string_literal: true

require 'fileutils'
require 'optparse'

module PackmanNova
  class Cli
    PROGRAM_NAME = ::PackmanNova::Cli::OptionParsers::PROGRAM_NAME
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
      @parsers = ::PackmanNova::Cli::OptionParsers.new(global: global, commands: COMMANDS)
    end

    def call
      run
    rescue ::StandardError, ::Interrupt => e
      exit_code_for(e)
    ensure
      log_file&.close
    end

    def verbose?
      global.fetch(:verbose, false)
    end

    private

    attr_reader :argv, :out, :err, :global, :parsers, :logger, :log_file

    def run
      parsers.global_parser.order!(argv)
      return print_and_succeed(::PackmanNova::VERSION) if global[:version]
      return print_and_succeed(parsers.global_parser) if global[:help]

      dispatch(argv.shift)
    end

    def dispatch(name)
      command_class = COMMANDS.fetch(name) { raise ::OptionParser::InvalidArgument, name ? "unknown command '#{name}'" : 'no command given' }
      options = {}
      parser = parsers.command_parser(name, command_class, options)
      parser.parse!(argv)
      return print_and_succeed(parser) if options[:help]

      config, config_error = load_config(command_class)
      @logger = build_logger(name, command_class, config)
      command_class.new(config: config, logger: logger, options: options, args: argv, out: out, config_error: config_error).call
    end

    def load_config(command_class)
      overrides = { workdir: global[:workdir] && ::File.expand_path(global[:workdir]), offline: global[:offline] }.compact
      [::PackmanNova::Config.load(path: global[:config], overrides: overrides), nil]
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
