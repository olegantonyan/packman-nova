# frozen_string_literal: true

module PackmanNova
  class Cli
    class Report
      LABELS = { ok: ['ok', :green], warn: ['warn', :yellow], fail: ['fail', :red], skip: ['skip', :dim] }.freeze

      def initialize(out:)
        @out = out
        @failures = 0
      end

      attr_reader :failures

      def call(status, name, detail)
        @failures += 1 if status == :fail
        text, color = LABELS.fetch(status)
        label = ::PackmanNova::Utils::Color.enabled?(out) ? ::PackmanNova::Utils::Color.paint(text.ljust(4), color) : text.ljust(4)
        out.puts("#{label}  #{name.ljust(10)} #{detail}")
      end

      private

      attr_reader :out
    end
  end
end
