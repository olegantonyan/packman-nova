# frozen_string_literal: true

module PackmanNova
  class Sync
    ExpectedFile = ::Data.define(:name, :source, :md5, :sha256, :blob) do
      def initialize(name:, source: nil, md5: nil, sha256: nil, blob: false)
        super
      end

      def satisfied_by?(path)
        return false unless ::File.file?(path)
        return true if linked_to_source?(path)
        return ::PackmanNova::Utils::Digest.md5_file(path) == md5 if md5
        return ::PackmanNova::Utils::Digest.sha256_file(path) == sha256 if sha256

        false
      end

      def available?
        !source.nil? && ::File.file?(source)
      end

      private

      def linked_to_source?(path)
        blob && available? && ::File.identical?(path, source)
      end
    end
  end
end
