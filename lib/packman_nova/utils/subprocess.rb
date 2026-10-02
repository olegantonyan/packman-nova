# frozen_string_literal: true

require 'logger'
require 'open3'

module PackmanNova
  module Utils
    class Subprocess
      DEFAULT_TIMEOUT_SEC = 43_200
      CAPTURE_TIMEOUT_SEC = 600
      TERM_TIMEOUT_SEC = 10
      OUTPUT_PROGNAME = 'container'
      SPAWN_ERRORS = [::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOEXEC].freeze

      def initialize(logger:)
        @logger = logger
      end

      def execute(argv, env: {}, chdir: nil, timeout_sec: DEFAULT_TIMEOUT_SEC, term_timeout_sec: TERM_TIMEOUT_SEC, log_output: true, &line_block)
        logger.command(argv)
        popen(:popen2e, argv, env, chdir) do |stdin, output, wait_thr|
          stdin.close
          reader = start_thread { output.each_line { |line| emit(line.scrub, log_output, line_block) } }
          finished = await(wait_thr, timeout_sec, term_timeout_sec, argv)
          finish_reader(reader, finished, term_timeout_sec)
          wait_thr.value
        end
      end

      def capture(argv, env: {}, chdir: nil, timeout_sec: CAPTURE_TIMEOUT_SEC)
        status, stdout, stderr = run_captured(argv, env: env, chdir: chdir, timeout_sec: timeout_sec)
        raise ::PackmanNova::SubprocessError.new(cli: argv, status: status, output: stderr) unless status.success?

        stdout
      end

      def capture?(argv, env: {}, chdir: nil, timeout_sec: CAPTURE_TIMEOUT_SEC)
        status, stdout, stderr = run_captured(argv, env: env, chdir: chdir, timeout_sec: timeout_sec)
        [status.success?, stdout + stderr]
      rescue ::PackmanNova::SubprocessError => e
        [false, e.message]
      end

      private

      attr_reader :logger

      def run_captured(argv, env:, chdir:, timeout_sec:)
        logger.command(argv, level: ::Logger::DEBUG)
        popen(:popen3, argv, env, chdir) do |stdin, stdout, stderr, wait_thr|
          stdin.close
          readers = [stdout, stderr].map { |io| start_thread { io.read.scrub } }
          await(wait_thr, timeout_sec, TERM_TIMEOUT_SEC, argv)
          [wait_thr.value, *readers.map(&:value)]
        end
      end

      def popen(method, argv, env, chdir, &)
        ::Open3.public_send(method, stringify(env), *argv.map(&:to_s), **spawn_options(chdir), &)
      rescue *SPAWN_ERRORS => e
        raise ::PackmanNova::SubprocessError.new(e.message, cli: argv, status: nil)
      end

      def finish_reader(reader, process_finished, term_timeout_sec)
        return reader.join if process_finished

        reader.join(term_timeout_sec) || reader.kill
      end

      def emit(line, log_output, line_block)
        logger.add(::Logger::INFO, line, OUTPUT_PROGNAME) if log_output
        line_block&.call(line)
      end

      def await(wait_thr, timeout_sec, term_timeout_sec, argv)
        return true if wait_thr.join(timeout_sec)

        logger.warn("timeout after #{timeout_sec}s, terminating pid #{wait_thr.pid}: #{argv.first}")
        signal(wait_thr.pid, 'TERM')
        return false if wait_thr.join(term_timeout_sec)

        signal(wait_thr.pid, 'KILL')
        wait_thr.join
        false
      end

      def signal(pid, name)
        ::Process.kill(name, pid)
      rescue ::Errno::ESRCH
        nil
      end

      def start_thread(&)
        thread = ::Thread.new(&)
        thread.report_on_exception = false
        thread
      end

      def stringify(env)
        env.to_h { |key, value| [key.to_s, value&.to_s] }
      end

      def spawn_options(chdir)
        chdir ? { chdir: chdir.to_s } : {}
      end
    end
  end
end
