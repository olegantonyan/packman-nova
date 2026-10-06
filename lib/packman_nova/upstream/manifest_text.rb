# frozen_string_literal: true

module PackmanNova
  class Upstream
    class ManifestText
      TOP_LEVEL = /\A\S/
      WATCH_LINE = /\Awatch:\s*\n?\z/

      attr_reader :text

      def initialize(text)
        @text = text
      end

      def with_source(old_source, new_source)
        lines = text.lines
        start, item_prefix = source_start(lines, old_source.fetch('file'))
        dash = item_prefix.sub(/-\s+\z/, '-')
        finish = block_end(lines, start) { |line| line.start_with?(dash) }
        splice(lines, start, finish) { |segment| replace_values(segment, old_source, new_source, item_prefix.size) }
      end

      def with_commit(commit)
        lines = text.lines
        start = lines.index { |line| WATCH_LINE.match?(line) } || raise(::PackmanNova::UpstreamError, 'package.yml: no watch block')
        indent = lines[start + 1].to_s[/\A */].size
        splice(lines, start, block_end(lines, start) { false }) { |segment| set_value(segment, 'commit', commit, indent) }
      end

      private

      def source_start(lines, file)
        pattern = /\A(\s*-\s+)file:\s*(["']?)#{::Regexp.escape(file)}\2\s*\z/
        lines.each_with_index do |line, index|
          match = pattern.match(line)
          return [index, match[1]] if match
        end
        raise ::PackmanNova::UpstreamError, "package.yml: no block-style source entry for #{file}"
      end

      def splice(lines, start, finish)
        self.class.new((lines[0...start] + [yield(lines[start...finish].join)] + lines[finish..]).join)
      end

      def block_end(lines, start)
        offset = lines[(start + 1)..].index { |line| TOP_LEVEL.match?(line) || yield(line) }
        offset ? start + 1 + offset : lines.size
      end

      def replace_values(segment, old_source, new_source, key_indent)
        segment = segment.sub(old_source.fetch('file'), new_source.fetch('file'))
        old_source.fetch('urls', []).zip(new_source.fetch('urls', [])).each { |old_url, new_url| segment = segment.sub(old_url, new_url) }
        %w[sha256 size].reduce(segment) { |text, key| set_value(text, key, new_source.fetch(key), key_indent) }
      end

      def set_value(segment, key, value, indent)
        line = "#{' ' * indent}#{key}: #{value}"
        pattern = /^#{' ' * indent}#{key}:.*$/
        return segment.sub(pattern) { line } if pattern.match?(segment)

        "#{segment.chomp}\n#{line}\n"
      end
    end
  end
end
