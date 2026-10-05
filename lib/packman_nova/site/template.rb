# frozen_string_literal: true

require 'erb'

module PackmanNova
  module Site
    class Template
      DIR = ::File.join(__dir__, 'templates')
      VIEWS = ::Hash.new do |views, members|
        views[members] = ::Data.define(*members) { define_method(:h) { |value| ::ERB::Util.html_escape(value) } }
      end

      class << self
        def read(name)
          ::File.read(::File.join(DIR, name))
        end

        def load(name)
          new(source: read(name), name:)
        end
      end

      def initialize(source:, name: 'template')
        @name = name
        @erb = ::ERB.new(source, trim_mode: '-')
        @erb.filename = name
      end

      def render(assigns)
        erb.result(wrap(assigns).instance_eval { binding })
      rescue ::StandardError, ::SyntaxError => e
        raise ::PackmanNova::Error, "#{name}: #{e.message}"
      end

      private

      attr_reader :name, :erb

      def wrap(value)
        case value
        when ::Hash then VIEWS[value.keys.map(&:to_sym)].new(**value.to_h { |key, item| [key.to_sym, wrap(item)] })
        when ::Array then value.map { |item| wrap(item) }
        else value
        end
      end
    end
  end
end
