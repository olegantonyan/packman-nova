# frozen_string_literal: true

module PackmanNova
  module Site
    class Model
      KEY_FILE_NAME = ::PackmanNova::Repo::Layout::PUBLIC_KEY_FILE
      GITHUB_REPO = %r{\Ahttps://github\.com/([^/]+/[^/]+?)/?\z}
      WORKFLOW_FILE = 'build-publish.yml'
      OG_IMAGE_FILE = 'og-image.png'
      THEME_COLOR = '#73ba25'
      BACKGROUND_COLOR = '#0f1117'

      def initialize(config:, states:)
        @config = config
        @states = states
      end

      def distros
        @distros ||= config.siblings.map { |sibling| ::PackmanNova::Site::DistroModel.new(config: sibling, state: states[sibling.distro.id]) }
      end

      def public_url
        ::PackmanNova::Repo::Layout.from_config(config, root: ::PackmanNova::Repo::Layout.localfs_root(config)).public_url(config.repository.public_url)
      end

      def key_url
        "#{public_url}/#{KEY_FILE_NAME}"
      end

      def key
        key = ordered_states.map { |state| state['key'] }.find { |entry| entry.is_a?(::Hash) && entry.values_at('id', 'fingerprint').any? { |value| !value.to_s.empty? } }
        return nil unless key

        { 'id' => ::PackmanNova::Site::Format.hex_groups(key['id']), 'fingerprint' => ::PackmanNova::Site::Format.hex_groups(key['fingerprint']) }
      end

      def source_url
        url = config.site.source_url
        url.empty? ? nil : url
      end

      def pipeline_api_url
        repo = GITHUB_REPO.match(source_url.to_s)&.captures&.first
        "https://api.github.com/repos/#{repo}/actions/workflows/#{WORKFLOW_FILE}/runs?per_page=1" if repo
      end

      def generated_at_iso
        ordered_states.filter_map { |state| state['generated_at'] }.max
      end

      def site_url
        "#{public_url}/"
      end

      def structured_data
        data = {
          '@context' => 'https://schema.org', '@type' => 'SoftwareSourceCode', 'name' => page_text['name'], 'description' => page_text['description'],
          'url' => site_url, 'codeRepository' => source_url, 'dateModified' => generated_at_iso
        }.compact
        ::JSON.generate(data).gsub(/[<>&]/) { |char| format('\\u%04x', char.ord) }
      end

      def manifest
        icons = [192, 512].map { |size| { 'src' => "icon-#{size}.png", 'sizes' => "#{size}x#{size}", 'type' => 'image/png' } }
        ::JSON.pretty_generate(
          'name' => page_text['title'], 'short_name' => page_text['name'], 'description' => page_text['description'], 'start_url' => site_url,
          'display' => 'browser', 'theme_color' => THEME_COLOR, 'background_color' => BACKGROUND_COLOR, 'icons' => icons
        )
      end

      def to_h
        page_text.merge(
          'public_url' => public_url, 'site_url' => site_url, 'key_url' => key_url, 'key' => key, 'source_url' => source_url, 'pipeline_api_url' => pipeline_api_url,
          'structured_data' => structured_data, 'manifest' => manifest, 'og_image_url' => "#{site_url}#{OG_IMAGE_FILE}", 'distros' => distros.map(&:to_h),
          'generated_at' => ::PackmanNova::Site::Format.time(generated_at_iso), 'generated_at_iso' => generated_at_iso
        )
      end

      private

      attr_reader :config, :states

      def page_text
        { 'name' => config.site.name, 'title' => config.site.title, 'description' => config.site.description }
      end

      def ordered_states
        [states[config.distro.id], *states.values].compact
      end
    end
  end
end
