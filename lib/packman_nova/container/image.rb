# frozen_string_literal: true

require 'time'

module PackmanNova
  module Container
    class Image
      STATE_FILE_NAME = 'image.json'

      attr_reader :tag

      def initialize(runtime:, config:, logger:, subprocess:, workdir:, tag: nil)
        @runtime = runtime
        @config = config
        @logger = logger
        @subprocess = subprocess
        @workdir = workdir
        @tag = tag || config.container.image
      end

      def exists?
        subprocess.capture?([runtime.executable, 'image', 'inspect', tag]).first
      end

      def id
        subprocess.capture([runtime.executable, 'image', 'inspect', '--format', '{{.Id}}', tag]).strip
      end

      def containerfile
        config.resolve(config.container.containerfile)
      end

      def containerfile_sha256
        ::PackmanNova::Utils::Digest.sha256_file(containerfile)
      end

      def record
        ::PackmanNova::Utils::JsonFile.read(workdir.state_file(STATE_FILE_NAME), default: {})
      end

      def up_to_date?
        exists? && record['tag'] == tag && record['containerfile_sha256'] == containerfile_sha256
      end

      def build!(no_cache: false)
        argv = build_command(no_cache: no_cache)
        status = subprocess.execute(argv)
        raise ::PackmanNova::SubprocessError.new(cli: argv, status: status) unless status.success?

        write_record
      end

      def ensure!
        if up_to_date?
          logger.debug("image #{tag} is up to date")
        else
          logger.info("building image #{tag}")
          build!
        end
        id
      end

      def build_command(no_cache: false)
        [runtime.executable, 'build', *(no_cache ? ['--no-cache'] : []), '-t', tag, '-f', containerfile, ::File.dirname(containerfile)]
      end

      private

      attr_reader :runtime, :config, :logger, :subprocess, :workdir

      def write_record
        data = { 'tag' => tag, 'id' => id, 'containerfile_sha256' => containerfile_sha256, 'built_at' => ::Time.now.utc.iso8601 }
        ::PackmanNova::Utils::JsonFile.write(workdir.state_file(STATE_FILE_NAME), data)
        data
      end
    end
  end
end
