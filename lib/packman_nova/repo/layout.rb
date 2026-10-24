# frozen_string_literal: true

module PackmanNova
  module Repo
    class Layout
      SRC = 'src'
      STATE_FILE = 'state.json'
      INDEX_FILE = 'index.html'
      PACKAGES_FILE = 'packages.json'
      PUBLIC_KEY_FILE = 'packman-nova.key'
      REPO_FILE = 'packman-nova.repo'
      SITEMAP_FILE = 'sitemap.xml'
      ROBOTS_FILE = 'robots.txt'
      MANIFEST_FILE = 'site.webmanifest'
      LLMS_FILE = 'llms.txt'
      LLMS_FULL_FILE = 'llms-full.txt'
      SITE_ASSETS = %w[favicon.svg favicon.ico apple-touch-icon.png icon-192.png icon-512.png og-image.png].freeze
      SITE_FILES = [*SITE_ASSETS, MANIFEST_FILE, ROBOTS_FILE, SITEMAP_FILE, LLMS_FILE, LLMS_FULL_FILE, INDEX_FILE].freeze
      ROOT_FILES = [*SITE_FILES, PUBLIC_KEY_FILE].freeze
      REPODATA = 'repodata'
      LOGS = 'logs'

      class << self
        def from_config(config, root:)
          new(root:, path: config.repository.path)
        end

        def localfs_root(config)
          path = config.repository.localfs.path.strip
          path.empty? ? config.shared_repo_dir : ::File.expand_path(path)
        end
      end

      attr_reader :root, :path

      def initialize(root:, path:)
        @root = ::File.expand_path(root)
        @path = path.delete_prefix('/').delete_suffix('/')
        freeze
      end

      def repo_dir = ::File.join(root, path)
      def src_dir = ::File.join(repo_dir, SRC)
      def state_file = ::File.join(repo_dir, STATE_FILE)
      def packages_file = ::File.join(repo_dir, PACKAGES_FILE)
      def index_file = ::File.join(root, INDEX_FILE)
      def repo_file = ::File.join(repo_dir, REPO_FILE)
      def public_key_file = ::File.join(root, PUBLIC_KEY_FILE)
      def logs_dir = ::File.join(repo_dir, LOGS)
      def file(relative) = ::File.join(repo_dir, relative)
      def repodata_dir(subdir) = ::File.join(repo_dir, subdir, REPODATA)
      def repomd(subdir) = ::File.join(repodata_dir(subdir), 'repomd.xml')

      def public_url(configured)
        url = configured.strip.sub(%r{/+\z}, '')
        url.empty? ? "file://#{root}" : url
      end

      def managed?(key)
        key.start_with?("#{path}/") || ROOT_FILES.include?(key)
      end

      def state_key
        "#{path}/#{STATE_FILE}"
      end
    end
  end
end
