# frozen_string_literal: true

module PackmanNova
  module Repo
    class SigningKey
      def initialize(config:, gpg:, logger:)
        @config = config
        @gpg = gpg
        @logger = logger
      end

      def call
        private_armor = ::PackmanNova::Gpg.to_armor(encoded_private_key)
        info = gpg.info(private_armor)
        raise ::PackmanNova::PublishError, 'GPG_PRIVATE_KEY_BASE64 does not hold a private key' unless info.secret?

        logger.info("signing with key #{info.key_id} (#{info.uids.join(', ')})")
        ::PackmanNova::Gpg::Key.new(
          private_armor: private_armor, public_armor: gpg.public_key_from_private(private_armor), key_id: info.key_id, fingerprint: info.fingerprint
        )
      end

      private

      attr_reader :config, :gpg, :logger

      def encoded_private_key
        encoded = config.signing.gpg_private_key_base64
        raise ::PackmanNova::PublishError, 'signing.gpg_private_key_base64 (GPG_PRIVATE_KEY_BASE64) is empty; set it or pass --unsigned' if encoded.empty?

        encoded
      end
    end
  end
end
