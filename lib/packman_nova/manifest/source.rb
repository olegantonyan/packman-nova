# frozen_string_literal: true

module PackmanNova
  class Manifest
    class Source
      HTTP_PATTERN = %r{\Ahttps?://\S+\z}i
      PMBS_PREFIX = 'pmbs:'
      MIRROR_SRC_PREFIX = 'mirror-src:'
      SHA256_PATTERN = /\A\h{64}\z/
      GENERATED = %w[public-key].freeze

      class << self
        def scheme_of(url)
          return :http if HTTP_PATTERN.match?(url)
          return :pmbs if url.start_with?(PMBS_PREFIX) && !url.delete_prefix(PMBS_PREFIX).split('/', 2).first.to_s.empty?
          return :mirror_src if url.start_with?(MIRROR_SRC_PREFIX) && !url.delete_prefix(MIRROR_SRC_PREFIX).empty?

          nil
        end
      end

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

      def scheme(url)
        self.class.scheme_of(url) || raise(::ArgumentError, "unsupported source url: #{url}")
      end

      def pmbs_package(url)
        pmbs_parts(url).first
      end

      def pmbs_file(url)
        pmbs_parts(url)[1] || file
      end

      def mirror_package(url)
        raise ::ArgumentError, "not a mirror-src url: #{url}" unless scheme(url) == :mirror_src

        url.delete_prefix(MIRROR_SRC_PREFIX)
      end

      def to_h
        { file: file, urls: urls, sha256: sha256, size: size, path: path, generated: generated }.compact
      end

      private

      def pmbs_parts(url)
        raise ::ArgumentError, "not a pmbs url: #{url}" unless scheme(url) == :pmbs

        url.delete_prefix(PMBS_PREFIX).split('/', 2)
      end
    end
  end
end
