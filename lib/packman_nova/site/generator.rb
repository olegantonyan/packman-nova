# frozen_string_literal: true

require 'packman_nova/repo/layout'
require 'packman_nova/site/format'
require 'packman_nova/site/template'
require 'packman_nova/site/package_row'
require 'packman_nova/site/distro_model'
require 'packman_nova/site/model'
require 'packman_nova/site/states'

module PackmanNova
  module Site
    class Generator
      INDEX_TEMPLATE = 'index.html.erb'
      STYLESHEET = 'style.css'

      class << self
        def write_packages(path, state)
          ::PackmanNova::Utils::JsonFile.write(path, { 'generated_at' => state['generated_at'], 'packages' => state.fetch('packages', {}) })
        end
      end

      def initialize(config:, states:, logger:)
        @config = config
        @states = states
        @logger = logger
      end

      def render_index
        assigns = ::PackmanNova::Site::Model.new(config:, states:).to_h.merge('style' => ::PackmanNova::Site::Template.read(STYLESHEET))
        ::PackmanNova::Site::Template.load(INDEX_TEMPLATE).render(assigns)
      end

      def write_index(root)
        path = ::PackmanNova::Utils::Path.atomic_write(::File.join(root, ::PackmanNova::Repo::Layout::INDEX_FILE), render_index)
        logger.debug("site: wrote #{path}")
        path
      end

      private

      attr_reader :config, :states, :logger
    end
  end
end
