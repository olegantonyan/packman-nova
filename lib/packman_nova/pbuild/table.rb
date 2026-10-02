# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class Table
      SEPARATOR = '  '

      def initialize(headers:, rows:)
        @headers = headers.map(&:to_s)
        @rows = rows.map { |row| row.map { |cell| cell.nil? ? '-' : cell.to_s } }
      end

      def to_s
        widths = ([headers] + rows).transpose.map { |column| column.map(&:length).max }
        ([headers] + rows).map { |row| format_row(row, widths) }.join("\n").concat("\n")
      end

      private

      attr_reader :headers, :rows

      def format_row(row, widths)
        row.each_with_index.map { |cell, index| cell.ljust(widths[index]) }.join(SEPARATOR).rstrip
      end
    end
  end
end
