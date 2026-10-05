# frozen_string_literal: true

module PackmanNova
  class Release
    RUN_PATTERN = /(?:\A|-)\d+\.(\d+)\.nova\.\d+(?=\.|\z)/

    class << self
      def parse_run(string, template: nil)
        match = (template ? pattern_for(template) : RUN_PATTERN).match(string.to_s)
        match && ::Kernel.Integer(match[1], 10)
      end

      def pattern_for(template)
        parts = template.split(/(%\{\w+\})/).map do |part|
          case part
          when '%{run}' then '(\d+)'
          when /\A%\{\w+\}\z/ then '\d+'
          else ::Regexp.escape(part)
          end
        end
        /(?:\A|-)#{parts.join}(?=\.|\z)/
      end
    end

    attr_reader :template, :suse_version, :run

    def initialize(template:, suse_version:, run:)
      @template = template
      @suse_version = suse_version
      @run = run
      freeze
    end

    def to_s
      format(template, suse_version:, run:)
    rescue ::KeyError, ::ArgumentError => e
      raise ::PackmanNova::ConfigError, "release.template #{template.inspect}: #{e.message}"
    end
  end
end
