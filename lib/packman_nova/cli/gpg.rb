# frozen_string_literal: true

module PackmanNova
  class Cli
    class Gpg < ::PackmanNova::Cli::Command
      SUBCOMMANDS = %w[generate info convert export-public].freeze

      class << self
        def summary
          'manage the signing key'
        end

        def usage
          '<generate|info|convert|export-public> [FILE] [options]'
        end

        def log_file?
          false
        end

        def options(parser, options)
          parser.on('--name NAME', 'key owner name (generate)') { |value| options[:name] = value }
          parser.on('--email EMAIL', 'key owner email (generate)') { |value| options[:email] = value }
          parser.on('--format FORMAT', %w[base64 armor], 'output format: base64 or armor (generate)') { |value| options[:format] = value }
          parser.on('--from FORMAT', %w[base64 armor], 'input format (convert)') { |value| options[:from] = value }
          parser.on('--to FORMAT', %w[base64 armor], 'output format (convert)') { |value| options[:to] = value }
        end
      end

      def initialize(gpg: nil, input: $stdin, **)
        super(**)
        @gpg = gpg
        @input = input
      end

      def call
        subcommand = args.first
        raise ::OptionParser::InvalidArgument, "gpg: expected one of #{SUBCOMMANDS.join(', ')}" unless SUBCOMMANDS.include?(subcommand)

        send(:"run_#{subcommand.tr('-', '_')}")
        0
      end

      private

      attr_reader :input

      def run_generate
        key = gpg.generate(name: key_name, email: key_email)
        out.puts(formatted_private_key(key))
        generate_instructions(key).each { |line| logger.info(line) }
      end

      def formatted_private_key(key)
        options[:format] == 'armor' ? key.private_armor : key.private_base64
      end

      def key_name
        options[:name] || config.project_name
      end

      def key_email
        options[:email] || raise(::OptionParser::MissingArgument, '--email')
      end

      def generate_instructions(key)
        [
          "generated RSA 4096 key #{key.key_id} (#{key.fingerprint}) for #{key_name} <#{key_email}>",
          'keep this private key secret: put the line above into .env as GPG_PRIVATE_KEY_BASE64=<line> (or a CI secret)',
          "then run 'packman-nova gpg export-public' to write #{config.signing.public_key_file}"
        ]
      end

      def run_info
        info = gpg.info(key_input)
        [
          ['type:', info.secret? ? 'private' : 'public'], ['key id:', info.key_id], ['fingerprint:', info.fingerprint], *info.uids.map { |uid| ['uid:', uid] }
        ].each { |label, value| out.puts("#{label.ljust(12)} #{value}") }
        report_public_key_match(info)
      end

      def run_convert
        text = key_input
        detected = text.strip.start_with?(::PackmanNova::Gpg::ARMOR_PREFIX) ? 'armor' : 'base64'
        raise ::PackmanNova::GpgError, "input looks like #{detected}, not #{options[:from]}" if options[:from] && options[:from] != detected

        target = options[:to] || (detected == 'armor' ? 'base64' : 'armor')
        out.puts(::PackmanNova::Gpg.convert(text, to: target))
      end

      def run_export_public
        public_armor = gpg.public_key_from_private(configured_private_key)
        path = config.resolve(config.signing.public_key_file)
        ::PackmanNova::Utils::Path.atomic_write(path, public_armor)
        info = gpg.info(public_armor)
        logger.info("wrote public key #{info.key_id} (#{info.fingerprint}) to #{path}")
      end

      def key_input
        file = args[1]
        return ::File.read(file) if file && file != '-'
        return input.read if file == '-'

        configured_private_key
      end

      def configured_private_key
        encoded = config.signing.gpg_private_key_base64
        raise ::PackmanNova::GpgError, 'signing.gpg_private_key_base64 (GPG_PRIVATE_KEY_BASE64) is empty' if encoded.empty?

        encoded
      end

      def report_public_key_match(info)
        path = config.resolve(config.signing.public_key_file)
        return out.puts("#{'public key:'.ljust(12)} #{path} missing") unless ::File.file?(path)

        matches = gpg.info(::File.read(path)).same_key?(info)
        out.puts("#{'public key:'.ljust(12)} #{path} #{matches ? 'matches' : 'does NOT match'}")
      end

      def gpg
        @gpg ||= ::PackmanNova::Gpg.build(config: config, logger: logger)
      end
    end
  end
end
