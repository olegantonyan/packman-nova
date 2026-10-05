# frozen_string_literal: true

module PackmanNova
  class Manifest
    class Source
      HTTP_PATTERN = %r{\Ahttps?://\S+\z}i
      SHA256_PATTERN = /\A\h{64}\z/
      GENERATED = %w[public-key].freeze

      attr_reader :file, :urls, :sha256, :size, :path, :generated

      def initialize(file:, urls: [], sha256: nil, size: nil, path: nil, generated: nil)
        @file = file
        @urls = urls.dup.freeze
        @sha256 = sha256
        @size = size
        @path = path
        @generated = generated
        freeze
      end

      def local?
        !path.nil?
      end

      def generated?
        !generated.nil?
      end

      def remote?
        !local? && !generated?
      end

      def to_h
        { file:, urls:, sha256:, size:, path:, generated: }.compact
      end
    end
  end
end
