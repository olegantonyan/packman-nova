# frozen_string_literal: true

module PackmanNova
  class Sync
    Outcome = ::Data.define(:name, :status, :record, :detail, :checksums) do
      def initialize(name:, status:, record:, detail: nil, checksums: {})
        super
      end

      def changed?
        status == :changed
      end
    end
  end
end
