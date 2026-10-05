# frozen_string_literal: true

module PackmanNova
  module Logging
    class Multioutput
      LEVEL_PATTERN = /\A(\d\d:\d\d:\d\d )\[([DIWE])\]/

      attr_reader :outputs

      def initialize(*outputs, env: ::ENV)
        @outputs = outputs
        @colored = outputs.to_h { |io| [io, ::PackmanNova::Utils::Color.enabled?(io, env:)] }
      end

      def write(message)
        outputs.each do |io|
          io.write(colored[io] ? colorize(message) : message)
          io.flush if io.respond_to?(:flush)
        end
        message.bytesize
      end

      def close; end

      private

      attr_reader :colored

      def colorize(message)
        match = LEVEL_PATTERN.match(message)
        return message unless match

        case match[2]
        when 'I' then message.sub('[I]', ::PackmanNova::Utils::Color.paint('[I]', :green))
        when 'W' then paint_line(message, :yellow)
        when 'E' then paint_line(message, :red)
        else paint_line(message, :dim)
        end
      end

      def paint_line(message, color)
        "#{::PackmanNova::Utils::Color.paint(message.chomp, color)}\n"
      end
    end
  end
end
