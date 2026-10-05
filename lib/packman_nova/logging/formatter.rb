# frozen_string_literal: true

require 'logger'

module PackmanNova
  module Logging
    class Formatter < ::Logger::Formatter
      RAW_PROGNAME = 'container'
      MASK = '***'

      attr_reader :filters

      def initialize(filters: [])
        @filters = filters.map(&:to_s).reject(&:empty?).uniq.sort_by { |secret| -secret.length }.freeze
        super()
      end

      def call(severity, datetime, progname, msg)
        text = mask(msg2str(msg))
        return raw_line(text) if progname == RAW_PROGNAME

        "#{datetime.strftime('%H:%M:%S')} [#{severity[0]}] #{text}\n"
      end

      private

      def mask(text)
        filters.reduce(text) { |masked, secret| masked.gsub(secret, MASK) }
      end

      def raw_line(text)
        text.end_with?("\n") ? text : "#{text}\n"
      end
    end
  end
end
