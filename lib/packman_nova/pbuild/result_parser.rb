# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class ResultParser
      CODES = %w[broken succeeded failed unresolvable blocked scheduled waiting building excluded disabled locked].freeze
      FAILURE_CODES = %w[broken failed unresolvable].freeze
      HEADER = /\A(\w+):\s+(\d+)\s*\z/
      PACKAGE = /\A\s+(\S+)(?:\s+\((.*)\))?\s*\z/

      class << self
        def parse(text)
          new(text)
        end
      end

      attr_reader :packages_by_code, :counts, :details

      def initialize(text)
        @packages_by_code = {}
        @counts = {}
        @details = {}
        parse_lines(text.to_s.lines)
        [@packages_by_code, @counts, @details].each(&:freeze)
        freeze
      end

      def code_for(name)
        packages_by_code.find { |_code, names| names.include?(name) }&.first
      end

      def codes
        packages_by_code.each_with_object({}) { |(code, names), acc| names.each { |name| acc[name] = code } }
      end

      def failed?
        FAILURE_CODES.any? { |code| counts.fetch(code, 0).positive? }
      end

      private

      def parse_lines(lines)
        lines.reduce(nil) do |code, line|
          header = HEADER.match(line)
          next start_code(header) if header

          add_package(code, PACKAGE.match(line)) if code
          code
        end
      end

      def start_code(header)
        code = header[1]
        counts[code] = ::Kernel.Integer(header[2], 10)
        packages_by_code[code] = []
        code
      end

      def add_package(code, match)
        return unless match

        packages_by_code[code] << match[1]
        details[match[1]] = match[2] if match[2]
      end
    end
  end
end
