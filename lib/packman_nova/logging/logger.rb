# frozen_string_literal: true

require 'logger'
require 'shellwords'

module PackmanNova
  module Logging
    class Logger < ::Logger
      def initialize(outputs: [$stdout], level: ::Logger::INFO, filters: [])
        @outputs = outputs
        super(
          ::PackmanNova::Logging::Multioutput.new(*outputs),
          level:,
          formatter: ::PackmanNova::Logging::Formatter.new(filters:)
        )
      end

      def add_filters(*strings)
        self.class.new(outputs:, level:, filters: formatter.filters + strings)
      end

      def add_outputs(*ios)
        self.class.new(outputs: outputs + ios, level:, filters: formatter.filters)
      end

      def command(argv, level: ::Logger::INFO)
        add(level, "$ #{::Shellwords.join(argv.map(&:to_s))}")
      end

      private

      attr_reader :outputs
    end
  end
end
