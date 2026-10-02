# frozen_string_literal: true

module PackmanNova
  class Manifest
    Origin = ::Data.define(:project, :package, :pin) do
      def to_s
        "#{project}/#{package}"
      end
    end
  end
end
