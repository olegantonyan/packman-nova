# frozen_string_literal: true

require 'base64'

module PackmanNova
  class Gpg
    ARMOR_PREFIX = '-----BEGIN PGP '
    KEY_FILE = 'key.asc'
    BATCH_FILE = 'genkey.batch'

    class << self
      def build(config:, logger:, subprocess: ::PackmanNova::Utils::Subprocess.new(logger:))
        return new(executor: ::PackmanNova::Gpg::HostExecutor.new(subprocess:)) if ::PackmanNova::Gpg::HostExecutor.available?(subprocess)

        logger.debug('gpg not found on the host, running it in the builder container')
        new(executor: ::PackmanNova::Gpg::ContainerExecutor.build(config:, logger:, subprocess:))
      end

      def to_base64(text)
        ::Base64.strict_encode64(to_armor(text))
      end

      def to_armor(text)
        stripped = text.to_s.strip
        return "#{stripped}\n" if stripped.start_with?(ARMOR_PREFIX)

        decoded = ::Base64.strict_decode64(stripped.gsub(/\s+/, ''))
        raise ::PackmanNova::GpgError, 'key does not decode to an ASCII-armored PGP block' unless decoded.strip.start_with?(ARMOR_PREFIX)

        "#{decoded.strip}\n"
      rescue ::ArgumentError
        raise ::PackmanNova::GpgError, 'key is neither ASCII armor nor valid base64'
      end

      def convert(text, to:)
        to == 'armor' ? to_armor(text) : to_base64(text)
      end
    end

    def initialize(executor:)
      @executor = executor
    end

    def generate(name:, email:)
      validate_identity!(name, email)
      within_home do |home|
        home.gpg('--batch', '--no-tty', '--gen-key', home.write(BATCH_FILE, batch(name, email)))
        info = ::PackmanNova::Gpg::Info.parse(home.gpg('--with-colons', '--with-fingerprint', '--list-secret-keys'))
        ::PackmanNova::Gpg::Key.new(
          private_armor: home.gpg('--armor', '--export-secret-keys', info.fingerprint),
          public_armor: home.gpg('--armor', '--export', info.fingerprint),
          key_id: info.key_id, fingerprint: info.fingerprint
        )
      end
    end

    def info(armor_or_base64)
      within_home do |home|
        path = home.write(KEY_FILE, self.class.to_armor(armor_or_base64))
        ::PackmanNova::Gpg::Info.parse(home.gpg('--show-keys', '--with-colons', '--with-fingerprint', path))
      end
    end

    def public_key_from_private(armor_or_base64)
      within_home do |home|
        import(home, armor_or_base64)
        public_armor = home.gpg('--armor', '--export')
        raise ::PackmanNova::GpgError, 'no key found to export' if public_armor.strip.empty?

        public_armor
      end
    end

    private

    attr_reader :executor

    def within_home(&)
      ::PackmanNova::Gpg::Home.open(executor, &)
    end

    def import(home, armor_or_base64)
      home.gpg('--batch', '--import', home.write(KEY_FILE, self.class.to_armor(armor_or_base64)))
    end

    def validate_identity!(name, email)
      [name, email].each do |value|
        raise ::PackmanNova::GpgError, 'key name and email must be non-empty single-line strings' if value.to_s.strip.empty? || value.match?(/[\r\n]/)
      end
    end

    def batch(name, email)
      <<~BATCH
        Key-Type: RSA
        Key-Length: 4096
        Name-Real: #{name}
        Name-Email: #{email}
        Expire-Date: 0
        %no-ask-passphrase
        %no-protection
        %commit
      BATCH
    end
  end
end
