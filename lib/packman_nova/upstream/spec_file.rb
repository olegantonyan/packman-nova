# frozen_string_literal: true

module PackmanNova
  class Upstream
    class SpecFile
      VERSION_LINE = /^(Version:\s*)(\S+)/
      VERSIONED_LINE = /^(?:Source\d*:|%define\s|%global\s)/
      SOVER_LINE = /^(%define\s+sover\s+)(\S+)/
      WEAKREMOVER_LINE = /^Provides:(\s+)weakremover\((\S+)-\d+\)$/

      attr_reader :content

      def initialize(content)
        @content = content
      end

      def version
        content[VERSION_LINE, 2]
      end

      def sover
        content[SOVER_LINE, 2]
      end

      def with_version(old_version, new_version)
        lines = content.each_line.map do |line|
          if VERSION_LINE.match?(line)
            line.sub(VERSION_LINE) { "#{::Regexp.last_match(1)}#{::PackmanNova::Upstream::VersionText.rpm(new_version)}" }
          elsif VERSIONED_LINE.match?(line)
            ::PackmanNova::Upstream::VersionText.replace(line, old_version, new_version)
          else
            line
          end
        end
        self.class.new(lines.join)
      end

      def with_sover(old_sover, new_sover)
        text = content.sub(SOVER_LINE) { "#{::Regexp.last_match(1)}#{new_sover}" }
        self.class.new(add_weakremover(text, old_sover))
      end

      private

      def add_weakremover(text, old_sover)
        match = WEAKREMOVER_LINE.match(text)
        return text if match.nil? || text.include?("weakremover(#{match[2]}-#{old_sover})")

        text.sub(WEAKREMOVER_LINE) { "Provides:#{match[1]}weakremover(#{match[2]}-#{old_sover})\n#{::Regexp.last_match(0)}" }
      end
    end
  end
end
