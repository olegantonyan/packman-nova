# frozen_string_literal: true

module PackmanNova
  module Utils
    module Color
      CODES = { red: 31, green: 32, yellow: 33, dim: 2 }.freeze

      module_function

      def enabled?(io, env: ::ENV)
        io.respond_to?(:tty?) && io.tty? && env.fetch('NO_COLOR', '').empty?
      end

      def paint(text, color)
        "\e[#{CODES.fetch(color)}m#{text}\e[0m"
      end
    end
  end
end
