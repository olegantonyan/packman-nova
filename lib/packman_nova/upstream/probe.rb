# frozen_string_literal: true

module PackmanNova
  class Upstream
    Probe = ::Data.define(:version, :commit, :ref) do
      def label
        version || "#{ref}@#{commit.to_s[0, 8]}"
      end
    end
  end
end
