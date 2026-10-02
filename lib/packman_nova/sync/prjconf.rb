# frozen_string_literal: true

module PackmanNova
  class Sync
    class Prjconf
      FACTORY_CONF_NAME = 'tumbleweed.conf'
      RELEASE_LINE = /\A\s*Release\s*:/i

      Result = ::Data.define(:factory_md5, :local_md5, :factory_source)

      def initialize(config:, workdir:, downloader:, logger:)
        @config = config
        @workdir = workdir
        @downloader = downloader
        @logger = logger
      end

      def call(refresh: true, write: true)
        factory, source = factory_content(refresh)
        local = local_content
        if write
          write_if_changed(factory_path, factory)
          write_if_changed(workdir.config_file, local)
        end
        Result.new(factory_md5: md5(factory), local_md5: md5(local), factory_source: source)
      end

      def factory_path
        ::File.join(workdir.configs_dir, FACTORY_CONF_NAME)
      end

      def local_content
        ::File.read(config.resolve(config.prjconf.local)).lines.grep_v(RELEASE_LINE).join
      end

      private

      attr_reader :config, :workdir, :downloader, :logger

      def factory_content(refresh)
        fetched = fetch if refresh && !downloader.offline?
        fetched ? [fetched, config.prjconf.base_url] : offline_content
      end

      def offline_content
        return [::File.read(factory_path), factory_path] if ::File.file?(factory_path)

        fallback = config.resolve(config.prjconf.base_fallback)
        logger.warn("using fallback prjconf #{fallback}")
        [::File.read(fallback), fallback]
      end

      def fetch
        content = downloader.get(config.prjconf.base_url)
        cache_path = ::File.join(workdir.prjconf_cache_dir, "factory-#{md5(content)}.conf")
        ::PackmanNova::Utils::Path.atomic_write(cache_path, content) unless ::File.file?(cache_path)
        content
      rescue ::PackmanNova::DownloadError => e
        logger.warn("Factory prjconf: #{e.message}")
        nil
      end

      def write_if_changed(path, content)
        return if ::File.file?(path) && ::File.read(path) == content

        ::PackmanNova::Utils::Path.atomic_write(path, content)
      end

      def md5(content)
        ::PackmanNova::Utils::Digest.md5_string(content)
      end
    end
  end
end
