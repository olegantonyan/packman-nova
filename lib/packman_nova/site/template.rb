# frozen_string_literal: true

require 'erb'
require 'packman_nova/site/view'

module PackmanNova
  module Site
    class Template
      DIR = ::File.join(__dir__, 'templates')

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
        @erb = ::ERB.new(source, trim_mode: '-')
        @erb.filename = name
      end

      def render(assigns)
        erb.result(::PackmanNova::Site::View.wrap(assigns).instance_eval { binding })
      rescue ::StandardError, ::SyntaxError => e
        raise ::PackmanNova::Error, "#{name}: #{e.message}"
      end

      private

      attr_reader :name, :erb
    end
  end
end
