# frozen_string_literal: true

module PackmanNova
  module Sources
    class RpmVersion
      include ::Comparable

      SEGMENT = /\d+|[A-Za-z]+/

      attr_reader :segments

      def initialize(string)
        @segments = string.to_s.scan(SEGMENT).freeze
        freeze
      end

      def <=>(other)
        length = [segments.size, other.segments.size].max
        (0...length).each do |index|
          result = compare_segment(segments[index], other.segments[index])
          return result unless result.zero?
        end
        0
      end

      def to_s
        segments.join('.')
      end

      private

      def compare_segment(left, right)
        return presence(left) <=> presence(right) if left.nil? || right.nil?
        return numeric?(left) ? 1 : -1 if numeric?(left) != numeric?(right)

        numeric?(left) ? left.to_i <=> right.to_i : left <=> right
      end

      def presence(segment)
        segment.nil? ? 0 : 1
      end

      def numeric?(segment)
        segment.match?(/\A\d/)
      end
    end
  end
end
