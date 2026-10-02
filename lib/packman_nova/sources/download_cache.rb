# frozen_string_literal: true

require 'fileutils'
require 'securerandom'

module PackmanNova
  module Sources
    class DownloadCache
      Blob = ::Data.define(:path, :sha256, :size)

      def initialize(workdir:)
        @workdir = workdir
      end

      def sha256_path(sha256)
        workdir.cache_blob(sha256: sha256)
      end

      def md5_path(md5)
        workdir.cache_blob(md5: md5)
      end

      def cached(sha256:, size: nil)
        path = sha256_path(sha256)
        return nil unless present?(path, size)

        Blob.new(path: path, sha256: sha256, size: ::File.size(path))
      end

      def fetch(sha256:, size:, &)
        (sha256 && cached(sha256: sha256, size: size)) || store_sha256(sha256, size, &)
      end

      def store_md5(md5:, size: nil)
        path = md5_path(md5)
        return path if present?(path, size)

        with_temp(path) do |tmp|
          yield tmp
          verify(tmp, size: size, digest: md5, actual: ::PackmanNova::Utils::Digest.md5_file(tmp), kind: 'md5')
          ::File.rename(tmp, path)
          path
        end
      end

      private

      attr_reader :workdir

      def store_sha256(sha256, size)
        with_temp(sha256_path(sha256 || 'unknown')) do |tmp|
          yield tmp
          actual = ::PackmanNova::Utils::Digest.sha256_file(tmp)
          verify(tmp, size: size, digest: sha256, actual: actual, kind: 'sha256')
          path = sha256_path(actual)
          ::File.rename(tmp, path)
          Blob.new(path: path, sha256: actual, size: ::File.size(path))
        end
      end

      def present?(path, size)
        ::File.file?(path) && (size.nil? || ::File.size(path) == size)
      end

      def verify(tmp, size:, digest:, actual:, kind:)
        raise ::PackmanNova::Sources::ChecksumMismatch, "download produced no file at #{tmp}" unless ::File.file?(tmp)

        actual_size = ::File.size(tmp)
        raise ::PackmanNova::Sources::ChecksumMismatch, "size #{actual_size}, expected #{size}" if size && actual_size != size
        raise ::PackmanNova::Sources::ChecksumMismatch, "#{kind} #{actual}, expected #{digest}" if digest && actual != digest
      end

      def with_temp(final_path)
        dir = ::PackmanNova::Utils::Path.mkpath(::File.dirname(final_path))
        tmp = ::File.join(dir, ".tmp-#{::Process.pid}-#{::SecureRandom.hex(6)}")
        yield tmp
      ensure
        ::FileUtils.rm_f(tmp) if tmp
      end
    end
  end
end
