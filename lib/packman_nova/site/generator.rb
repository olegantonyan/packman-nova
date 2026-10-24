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
      STYLESHEET = 'style.css'
      ASSETS_DIR = ::File.join(__dir__, 'assets')

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

      def render(name)
        ::PackmanNova::Site::Template.load("#{name}.erb").render(assigns)
      end

      def write(root)
        ::PackmanNova::Repo::Layout::SITE_FILES.map do |name|
          path = ::PackmanNova::Utils::Path.atomic_write(::File.join(root, name), content(name))
          logger.debug("site: wrote #{path}")
          path
        end
      end

      private

      attr_reader :config, :states, :logger

      def content(name)
        ::PackmanNova::Repo::Layout::SITE_ASSETS.include?(name) ? ::File.binread(::File.join(ASSETS_DIR, name)) : render(name)
      end

      def assigns
        @assigns ||= ::PackmanNova::Site::Model.new(config:, states:).to_h.merge('style' => ::PackmanNova::Site::Template.read(STYLESHEET))
      end
    end
  end
end
