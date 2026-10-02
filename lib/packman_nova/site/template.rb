# frozen_string_literal: true

require 'liquid'

module PackmanNova
  module Site
    class Template
      DIR = ::File.join(__dir__, 'templates')
      RENDER_OPTIONS = { strict_variables: true, strict_filters: true }.freeze

      class << self
        def read(name)
          ::File.read(::File.join(DIR, name))
        end

        def load(name)
          new(source: read(name), name: name)
        end
      end

      def initialize(source:, name: 'template')
        @name = name
        @liquid = wrap_errors { ::Liquid::Template.parse(source, error_mode: :strict) }
      end

      def render(assigns)
        wrap_errors { liquid.render!(assigns, RENDER_OPTIONS) }
      end

      private

      attr_reader :name, :liquid

      def wrap_errors
        yield
      rescue ::Liquid::Error => e
        raise ::PackmanNova::Error, "#{name}: #{e.message}"
      end
    end
  end
end
