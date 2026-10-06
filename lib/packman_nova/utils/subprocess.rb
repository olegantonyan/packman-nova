# frozen_string_literal: true

require 'logger'
require 'open3'

module PackmanNova
  module Utils
    class Subprocess
      DEFAULT_TIMEOUT_SEC = 43_200
      CAPTURE_TIMEOUT_SEC = 600
      TERM_TIMEOUT_SEC = 10
      SPAWN_ERRORS = [::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOEXEC].freeze

      def initialize(logger:)
        @logger = logger
      end

      def execute(argv, env: {}, timeout_sec: DEFAULT_TIMEOUT_SEC, &line_block)
        logger.command(argv)
        popen(:popen2e, argv, env) do |stdin, output, wait_thr|
          stdin.close
          reader = start_thread { output.each_line { |line| emit(line.scrub, line_block) } }
          finished = await(wait_thr, timeout_sec, argv)
          finish_reader(reader, finished)
          wait_thr.value
        end
      end

      def capture(argv, env: {}, timeout_sec: CAPTURE_TIMEOUT_SEC)
        status, stdout, stderr = run_captured(argv, env:, timeout_sec:)
        raise ::PackmanNova::SubprocessError.new(cli: argv, status:, output: stderr) unless status.success?

        stdout
      end

      def capture?(argv, env: {}, timeout_sec: CAPTURE_TIMEOUT_SEC)
        status, stdout, stderr = run_captured(argv, env:, timeout_sec:)
        [status.success?, stdout + stderr]
      rescue ::PackmanNova::SubprocessError => e
        [false, e.message]
      end

      private

      attr_reader :logger

      def run_captured(argv, env:, timeout_sec:)
        logger.command(argv, level: ::Logger::DEBUG)
        popen(:popen3, argv, env) do |stdin, stdout, stderr, wait_thr|
          stdin.close
          readers = [stdout, stderr].map { |io| start_thread { io.read.scrub } }
          await(wait_thr, timeout_sec, argv)
          [wait_thr.value, *readers.map(&:value)]
        end
      end

      def popen(method, argv, env, &)
        ::Open3.public_send(method, stringify(env), *argv.map(&:to_s), &)
      rescue *SPAWN_ERRORS => e
        raise ::PackmanNova::SubprocessError.new(e.message, cli: argv, status: nil)
      end

      def finish_reader(reader, process_finished)
        return reader.join if process_finished

        reader.join(TERM_TIMEOUT_SEC) || reader.kill
      end

      def emit(line, line_block)
        line = visible_part(line)
        logger.add(::Logger::INFO, line, ::PackmanNova::Logging::Formatter::RAW_PROGNAME)
        line_block&.call(line)
      end

      def await(wait_thr, timeout_sec, argv)
        return true if wait_thr.join(timeout_sec)

        logger.warn("timeout after #{timeout_sec}s, terminating pid #{wait_thr.pid}: #{argv.first}")
        signal(wait_thr.pid, 'TERM')
        return false if wait_thr.join(TERM_TIMEOUT_SEC)

        signal(wait_thr.pid, 'KILL')
        wait_thr.join
        false
      end

      def signal(pid, name)
        ::Process.kill(name, pid)
      rescue ::Errno::ESRCH
        nil
      end

      def visible_part(line)
        line.sub(/\r+\n\z/, "\n").split("\r").last.to_s
      end

      def start_thread(&)
        thread = ::Thread.new(&)
        thread.report_on_exception = false
        thread
      end

      def stringify(env)
        env.to_h { |key, value| [key.to_s, value&.to_s] }
      end
    end
  end
end
