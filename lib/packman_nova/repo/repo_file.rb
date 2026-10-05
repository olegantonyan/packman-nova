# frozen_string_literal: true

module PackmanNova
  module Repo
    class RepoFile
      PRIORITY = 80

      def initialize(config:, layout:, signed: true)
        @config = config
        @layout = layout
        @signed = signed
      end

      def render
        <<~REPO
          [#{config.repository.slug}]
          name=#{name}
          type=rpm-md
          baseurl=#{base_url}/#{layout.path}/$basearch
          gpgcheck=#{signed ? 1 : 0}
          gpgkey=#{base_url}/#{::PackmanNova::Repo::Layout::PUBLIC_KEY_FILE}
          enabled=1
          autorefresh=1
          priority=#{PRIORITY}
        REPO
      end

      def name
        label = ::File.basename(layout.path).split(/[-_]/).map(&:capitalize).join(' ')
        "#{config.project_name} #{label} (#{config.distro.name})"
      end

      private

      attr_reader :config, :layout, :signed

      def base_url
        layout.public_url(config.repository.public_url)
      end
    end
  end
end
