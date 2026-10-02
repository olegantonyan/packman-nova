# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  module Sources
    class SrpmExtractor
      SCRIPT = 'rpm2cpio "$1" | cpio -i --quiet --to-stdout "$2" "./$2" > "$3"'
      TIMEOUT_SEC = 900
      OUTPUT_NAME = 'member'

      def initialize(config:, logger:, workdir:, runner: nil, image: nil)
        @config = config
        @logger = logger
        @workdir = workdir
        @runner = runner
        @image = image
      end

      def extract(srpm:, member:, target:)
        ensure_image!
        workdir.mktmpdir('srpm-') do |out_dir|
          run(srpm, member, out_dir)
          extracted = ::File.join(out_dir, OUTPUT_NAME)
          raise ::PackmanNova::SyncError, "#{member} not found in #{::File.basename(srpm)}" unless ::File.size?(extracted)

          ::FileUtils.mv(extracted, target)
        end
        target
      end

      def command(srpm:, member:, out_dir:)
        runner.command(**container_arguments(srpm, member, out_dir))
      end

      private

      attr_reader :config, :logger, :workdir

      def run(srpm, member, out_dir)
        arguments = container_arguments(srpm, member, out_dir)
        status = runner.run(timeout_sec: TIMEOUT_SEC, **arguments)
        raise ::PackmanNova::SubprocessError.new(cli: runner.command(**arguments), status: status) unless status.success?
      end

      def container_arguments(srpm, member, out_dir)
        {
          image: config.container.image,
          args: ['-c', SCRIPT, 'sh', "/in/#{::File.basename(srpm)}", member, "/out/#{OUTPUT_NAME}"],
          mounts: [
            ::PackmanNova::Container::Mount.new(source: ::File.dirname(srpm), target: '/in', readonly: true),
            ::PackmanNova::Container::Mount.new(source: out_dir, target: '/out')
          ],
          extra_args: ['--entrypoint', '/bin/sh', '--network', 'none']
        }
      end

      def ensure_image!
        return if image.exists?

        raise ::PackmanNova::SyncError, "builder image #{image.tag} is missing; run 'packman-nova image build' (needed for mirror-src extraction)"
      end

      def runner
        @runner ||= ::PackmanNova::Container::Runner.new(runtime: runtime, logger: logger, subprocess: subprocess)
      end

      def image
        @image ||= ::PackmanNova::Container::Image.new(runtime: runtime, config: config, logger: logger, subprocess: subprocess, workdir: workdir)
      end

      def runtime
        @runtime ||= ::PackmanNova::Container::Runtime.detect(config: config)
      end

      def subprocess
        @subprocess ||= ::PackmanNova::Utils::Subprocess.new(logger: logger)
      end
    end
  end
end
