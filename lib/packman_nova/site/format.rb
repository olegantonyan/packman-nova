# frozen_string_literal: true

require 'time'

module PackmanNova
  module Site
    module Format
      SIZE_UNITS = %w[B KiB MiB GiB TiB].freeze
      TIME_FORMAT = '%Y-%m-%d %H:%M UTC'
      HEX_GROUP = /.{1,4}/

      module_function

      def hex_groups(value)
        compact = value.to_s.delete(' ').upcase
        compact.empty? ? nil : compact.scan(HEX_GROUP).join(' ')
      end

      def time(iso)
        return nil if iso.to_s.empty?

        ::Time.iso8601(iso.to_s).utc.strftime(TIME_FORMAT)
      rescue ::ArgumentError
        iso.to_s
      end

      def size(bytes)
        bytes = bytes.to_i
        exponent = bytes < 1024 ? 0 : [::Math.log(bytes, 1024).floor, SIZE_UNITS.size - 1].min
        return "#{bytes} B" if exponent.zero?

        format('%.1f %s', bytes.fdiv(1024**exponent), SIZE_UNITS.fetch(exponent))
      end

      def anchor(name)
        "pkg-#{name.to_s.gsub(/[^A-Za-z0-9_.-]+/, '-')}"
      end
    end
  end
end
