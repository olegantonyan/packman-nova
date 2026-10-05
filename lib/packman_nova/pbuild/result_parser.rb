# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class ResultParser
      CODES = %w[broken succeeded failed unresolvable blocked scheduled waiting building excluded disabled locked].freeze
      SUCCEEDED = 'succeeded'
      FAILURE_CODES = %w[broken failed unresolvable].freeze
      HEADER = /\A(\w+):\s+(\d+)\s*\z/
      PACKAGE = /\A\s+(\S+)(?:\s+\((.*)\))?\s*\z/

      class << self
        def parse(text)
          new(text)
        end
      end

      attr_reader :codes, :details

      def initialize(text)
        @codes = {}
        @details = {}
        parse_lines(text.to_s.lines)
        [@codes, @details].each(&:freeze)
        freeze
      end

      private

      def parse_lines(lines)
        lines.reduce(nil) do |code, line|
          header = HEADER.match(line)
          next header[1] if header

          add_package(code, PACKAGE.match(line)) if code
          code
        end
      end

      def add_package(code, match)
        return unless match

        codes[match[1]] = code
        details[match[1]] = match[2] if match[2]
      end
    end
  end
end
