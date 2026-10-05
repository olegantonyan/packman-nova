# frozen_string_literal: true

module PackmanNova
  class Sync
    class PublicKey
      def initialize(config:, logger:, workdir:, gpg: nil)
        @config = config
        @logger = logger
        @workdir = workdir
        @gpg = gpg
      end

      def path
        @path ||= write(derive)
      end

      private

      attr_reader :config, :logger, :workdir

      def derive
        encoded = config.signing.gpg_private_key_base64
        raise ::PackmanNova::SyncError, 'GPG_PRIVATE_KEY_BASE64 is empty; the public key is derived from it' if encoded.empty?

        gpg.public_key_from_private(encoded)
      end

      def write(armor)
        path = workdir.public_key_file
        ::PackmanNova::Utils::Path.atomic_write(path, armor) unless ::File.file?(path) && ::File.read(path) == armor
        path
      end

      def gpg
        @gpg ||= ::PackmanNova::Gpg.build(config:, logger:)
      end
    end
  end
end
