# frozen_string_literal: true

require 'digest'

module PackmanNova
  module Utils
    module Digest
      module_function

      def sha256_file(path)
        ::Digest::SHA256.file(path).hexdigest
      end

      def md5_file(path)
        ::Digest::MD5.file(path).hexdigest
      end

      def sha256_string(string)
        ::Digest::SHA256.hexdigest(string)
      end

      def md5_string(string)
        ::Digest::MD5.hexdigest(string)
      end
    end
  end
end
