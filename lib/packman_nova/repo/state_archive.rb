# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  module Repo
    class StateArchive
      KEY = "#{::PackmanNova::Repo::Providers::S3::STATE_PREFIX}state.tar.zst".freeze
      FILE_NAME = 'state.tar.zst'
      CONTENT_TYPE = 'application/zstd'

      def initialize(config:, workdir:, provider:, subprocess:, logger:)
        @config = config
        @workdir = workdir
        @provider = provider
        @subprocess = subprocess
        @logger = logger
      end

      def entries
        dirs = [*results_dirs, workdir.state_dir].select { |dir| ::File.directory?(dir) }
        dirs.map { |dir| dir.delete_prefix("#{workdir.root}/") }
      end

      def push
        paths = entries
        raise ::PackmanNova::PublishError, "nothing to push: no results or state under #{workdir.root}" if paths.empty?

        with_archive do |archive|
          run!(['tar', '--zstd', '-cf', archive, '-C', workdir.root, *paths])
          logger.info("state: uploading #{paths.join(', ')} (#{::File.size(archive)} bytes) to #{KEY}")
          provider.upload(archive, KEY, content_type: CONTENT_TYPE)
        end
        paths
      end

      def pull(allow_missing: false)
        return missing(allow_missing) unless provider.exist?(KEY)

        with_archive do |archive|
          provider.download(KEY, archive)
          logger.info("state: extracting #{KEY} (#{::File.size(archive)} bytes) into #{workdir.root}")
          run!(['tar', '--zstd', '-xf', archive, '-C', workdir.root])
        end
        KEY
      end

      private

      attr_reader :config, :workdir, :provider, :subprocess, :logger

      def missing(allowed)
        raise ::PackmanNova::PublishError, "no state archive at #{KEY}" unless allowed

        logger.warn("state: no archive at #{KEY}, starting from an empty workdir")
        nil
      end

      def results_dirs
        config.distro.arches.map { |arch| workdir.results_dir(reponame: config.pbuild.reponame, arch: arch) }
      end

      def with_archive
        ::FileUtils.mkdir_p(workdir.root)
        workdir.mktmpdir('state-') { |dir| yield ::File.join(dir, FILE_NAME) }
      end

      def run!(argv)
        status = subprocess.execute(argv)
        raise ::PackmanNova::SubprocessError.new(cli: argv, status: status) unless status.success?
      end
    end
  end
end
