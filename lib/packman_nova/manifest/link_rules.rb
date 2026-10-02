# frozen_string_literal: true

module PackmanNova
  class Manifest
    LinkRules = ::Data.define(:delete) do
      def initialize(delete: [])
        super(delete: delete.dup.freeze)
      end

      def deletes?(file_name)
        delete.include?(file_name)
      end

      def empty?
        delete.empty?
      end
    end
  end
end
