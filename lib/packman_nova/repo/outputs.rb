# frozen_string_literal: true

module PackmanNova
  module Repo
    class Outputs
      def initialize(config:, logger:, site_generator: nil)
        @config = config
        @logger = logger
        @site_generator = site_generator
      end

      def write(layout:, previous:, state:, key: nil, site: true)
        state = persist_state(layout, previous, state)
        ::PackmanNova::Utils::Path.atomic_write(layout.repo_file, repo_file(layout, key))
        ::PackmanNova::Utils::Path.atomic_write(layout.public_key_file, key.public_armor) if key
        generate_site(layout, state, site)
        state
      end

      private

      attr_reader :config, :logger, :site_generator

      def persist_state(layout, previous, state)
        return previous if previous.same_content?(state) && ::File.file?(layout.state_file)

        state.write(layout.state_file)
        state
      end

      def repo_file(layout, key)
        base_url = ::PackmanNova::Repo::RepoFile.base_url(config: config, root: layout.root)
        ::PackmanNova::Repo::RepoFile.new(config: config, base_url: base_url, signed: !key.nil?).render
      end

      def generate_site(layout, state, site)
        return site_generator.new(config: config, state: state.to_h, logger: logger).write(layout.root) if site && site_generator

        logger.warn('site generator is not available, writing packages.json only') if site
        ::PackmanNova::Utils::JsonFile.write(layout.packages_file, { 'generated_at' => state.to_h['generated_at'], 'packages' => state.packages })
      end
    end
  end
end
