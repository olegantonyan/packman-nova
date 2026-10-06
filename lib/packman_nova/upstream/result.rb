# frozen_string_literal: true

module PackmanNova
  class Upstream
    Result = ::Data.define(:name, :state, :current, :latest, :detail) do
      def initialize(name:, state:, current: nil, latest: nil, detail: nil)
        super
      end

      def text
        return detail if detail
        return current if latest.nil? || state == :ok

        "#{current} -> #{latest}"
      end
    end
  end
end
