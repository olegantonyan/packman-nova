# frozen_string_literal: true

require 'packman_nova/repo/layout'
require 'packman_nova/site/format'
require 'packman_nova/site/template'
require 'packman_nova/site/package_row'
require 'packman_nova/site/model'

module PackmanNova
  module Site
    class Generator
      INDEX_TEMPLATE = 'index.html.erb'
      STYLESHEET = 'style.css'

      def initialize(config:, state:, logger:)
        @config = config
        @state = state
        @logger = logger
      end

      def render_index
        assigns = model.to_h.merge('style' => ::PackmanNova::Site::Template.read(STYLESHEET))
        ::PackmanNova::Site::Template.load(INDEX_TEMPLATE).render(assigns)
      end

      def write(dir, index: true)
        paths = [
          (::PackmanNova::Utils::Path.atomic_write(::File.join(dir, ::PackmanNova::Repo::Layout::INDEX_FILE), render_index) if index),
          ::PackmanNova::Utils::JsonFile.write(::File.join(dir, ::PackmanNova::Repo::Layout::PACKAGES_FILE), packages_document)
        ]
        paths.compact.each { |path| logger.debug("site: wrote #{path}") }
      end

      private

      attr_reader :config, :state, :logger

      def model
        @model ||= ::PackmanNova::Site::Model.new(config:, state:)
      end

      def packages_document
        { 'generated_at' => state['generated_at'], 'packages' => state.fetch('packages', {}) }
      end
    end
  end
end
