# frozen_string_literal: true

module PackmanNova
  class Upstream
    class ChangesEntry
      SEPARATOR = '-' * 67
      TIME_FORMAT = '%a %b %e %H:%M:%S UTC %Y'

      def initialize(packager:, clock: -> { ::Time.now })
        @packager = packager
        @clock = clock
      end

      def prepend(content, version)
        "#{SEPARATOR}\n#{clock.call.utc.strftime(TIME_FORMAT)} - #{packager}\n\n- Update to version #{version}\n\n#{content}"
      end

      private

      attr_reader :packager, :clock
    end
  end
end
