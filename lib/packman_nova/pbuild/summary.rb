# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class Summary
      HEADERS = %w[package code rpms time reason].freeze
      REASON_WIDTH = 100

      class << self
        def failed_packages(record)
          record.fetch('packages', {}).select { |_key, entry| ::PackmanNova::Pbuild::ResultParser::FAILURE_CODES.include?(entry['code']) }.keys
        end

        def duration(seconds)
          return nil unless seconds

          seconds < 60 ? "#{seconds}s" : format('%<m>dm%<s>02ds', m: seconds / 60, s: seconds % 60)
        end
      end

      def initialize(record:)
        @record = record
      end

      def to_s
        rows = record.fetch('packages', {}).map do |key, entry|
          [key, entry['code'], entry.fetch('rpms', []).size + entry.dig('baselibs', 'rpms').to_a.size, self.class.duration(entry['duration_sec']), reason(entry)]
        end
        "#{::PackmanNova::Pbuild::Table.new(headers: HEADERS, rows: rows)}#{footer}\n"
      end

      private

      attr_reader :record

      def reason(entry)
        text = entry['details'] || entry['reason']
        text && text.length > REASON_WIDTH ? "#{text[0, REASON_WIDTH - 3]}..." : text
      end

      def footer
        codes = record.fetch('codes', {}).map { |code, count| "#{code} #{count}" }.join(', ')
        built = record.fetch('built', []).size
        "run #{record['run']}, release #{record['release']}, built #{built} of #{record.fetch('packages', {}).size}: #{codes.empty? ? 'no packages' : codes}"
      end
    end
  end
end
