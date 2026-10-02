# frozen_string_literal: true

module PackmanNova
  module Sources
    module UrlSegment
      UNSAFE = /[^A-Za-z0-9._~:@!$&'()*+,;=-]/

      module_function

      def escape(segment)
        segment.to_s.gsub(UNSAFE) { |char| char.bytes.map { |byte| format('%%%02X', byte) }.join }
      end

      def query(pairs)
        text = pairs.compact.map { |key, value| "#{key}=#{escape(value)}" }.join('&')
        text.empty? ? '' : "?#{text}"
      end
    end
  end
end
