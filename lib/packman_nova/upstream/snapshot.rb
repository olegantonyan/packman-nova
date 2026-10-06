# frozen_string_literal: true

module PackmanNova
  class Upstream
    Snapshot = ::Data.define(:version, :commit, :file, :blob, :sover)
  end
end
