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

        key(private_armor, info, public_key_armor)
      end

      private

      attr_reader :config, :gpg, :logger

      def key(private_armor, info, public_armor)
        check_match!(info, gpg.info(public_armor))
        logger.info("signing with key #{info.key_id} (#{info.uids.join(', ')})")
        ::PackmanNova::Gpg::Key.new(private_armor: private_armor, public_armor: public_armor, key_id: info.key_id, fingerprint: info.fingerprint)
      end

      def encoded_private_key
        encoded = config.signing.gpg_private_key_base64
        raise ::PackmanNova::PublishError, 'signing.gpg_private_key_base64 (GPG_PRIVATE_KEY_BASE64) is empty; set it or pass --unsigned' if encoded.empty?

        encoded
      end

      def public_key_path
        config.resolve(config.signing.public_key_file)
      end

      def public_key_armor
        raise ::PackmanNova::PublishError, "public key #{public_key_path} is missing; run 'packman-nova gpg export-public'" unless ::File.file?(public_key_path)

        ::File.read(public_key_path)
      end

      def check_match!(private_info, public_info)
        return if private_info.same_key?(public_info)

        raise ::PackmanNova::PublishError,
              "#{public_key_path} (#{public_info.fingerprint}) does not match the signing key (#{private_info.fingerprint}); run 'packman-nova gpg export-public'"
      end
    end
  end
end
