# frozen_string_literal: true

module PackmanNova
  module Repo
    class RepoFile
      DISTRO_NAMES = { 'opensuse_tumbleweed' => 'openSUSE Tumbleweed' }.freeze
      PRIORITY = 80

      class << self
        def base_url(config:, root:)
          url = config.repository.public_url.to_s.strip
          url.empty? ? "file://#{::File.expand_path(root)}" : url.delete_suffix('/')
        end
      end

      def initialize(config:, base_url:, signed: true)
        @config = config
        @base_url = base_url
        @signed = signed
      end

      def render
        <<~REPO
          [#{config.repository.slug}]
          name=#{name}
          type=rpm-md
          baseurl=#{base_url}/#{repository_path}/$basearch
          gpgcheck=#{signed ? 1 : 0}
          gpgkey=#{base_url}/#{::PackmanNova::Repo::Layout::PUBLIC_KEY_FILE}
          enabled=1
          autorefresh=1
          priority=#{PRIORITY}
        REPO
      end

      def name
        label = ::File.basename(repository_path).split(/[-_]/).map(&:capitalize).join(' ')
        "#{config.project_name} #{label} (#{DISTRO_NAMES.fetch(config.distro.id, config.distro.id)})"
      end

      private

      attr_reader :config, :base_url, :signed

      def repository_path
        config.repository.path.delete_prefix('/').delete_suffix('/')
      end
    end
  end
end
