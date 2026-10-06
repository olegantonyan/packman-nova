# frozen_string_literal: true

module PackmanNova
  class Upstream
    class VersionCompare
      SEGMENT = /\d+|[a-zA-Z]+/
      DIGITS = /\A\d/

      class << self
        def compare(left, right)
          left_segments = left.scan(SEGMENT)
          right_segments = right.scan(SEGMENT)
          left_segments.zip(right_segments).each do |left_segment, right_segment|
            return 1 if right_segment.nil?

            result = compare_segments(left_segment, right_segment)
            return result unless result.zero?
          end
          left_segments.size <=> right_segments.size
        end

        def max(versions)
          versions.max { |left, right| compare(left, right) }
        end

        private

        def compare_segments(left, right)
          left_numeric = DIGITS.match?(left)
          return left_numeric ? 1 : -1 if left_numeric != DIGITS.match?(right)

          left_numeric ? left.to_i <=> right.to_i : left <=> right
        end
      end
    end
  end
end
