# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Gpg do
  let(:armor) { "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\nabc\n-----END PGP PUBLIC KEY BLOCK-----\n" }

  describe 'format conversion' do
    it 'round-trips armor through one-line base64' do
      encoded = ::PackmanNova::Gpg.to_base64(armor)

      refute_includes encoded, "\n"
      assert_equal armor, ::PackmanNova::Gpg.to_armor(encoded)
      assert_equal armor, ::PackmanNova::Gpg.convert(encoded, to: 'armor')
      assert_equal encoded, ::PackmanNova::Gpg.convert(armor, to: 'base64')
    end

    it 'accepts wrapped base64 and surrounding whitespace' do
      wrapped = ::PackmanNova::Gpg.to_base64(armor).scan(/.{1,20}/).join("\n")

      assert_equal armor, ::PackmanNova::Gpg.to_armor("  #{wrapped}\n")
    end

    it 'rejects input that is neither armor nor base64 of armor' do
      assert_raises(::PackmanNova::GpgError) { ::PackmanNova::Gpg.to_armor('not base64 !!') }
      assert_raises(::PackmanNova::GpgError) { ::PackmanNova::Gpg.to_armor(::Base64.strict_encode64('plain text')) }
      assert_raises(::ArgumentError) { ::PackmanNova::Gpg.convert(armor, to: 'binary') }
    end
  end

  describe ::PackmanNova::Gpg::Info do
    it 'parses key id, fingerprint and uids from colon output' do
      info = ::PackmanNova::Gpg::Info.parse(::File.read(fixture_path('repo', 'gpg-show-keys.txt')))

      assert_equal '31D7469FD4F5F9EF', info.key_id
      assert_equal '0EECDB2A7E2B144481F1800231D7469FD4F5F9EF', info.fingerprint
      assert_equal ['packman-nova WP3 test <wp3test@example.invalid>', 'Second: uid <second@example.invalid>'], info.uids
      assert_predicate info, :secret?
      assert_equal 'd4f5f9ef', info.short_id
    end

    it 'raises when no key is present' do
      assert_raises(::PackmanNova::GpgError) { ::PackmanNova::Gpg::Info.parse("tru::1:1790666442:0:3:1:5\n") }
    end
  end

  describe ::PackmanNova::Gpg::Key do
    it 'never shows key material in inspect' do
      key = ::PackmanNova::Gpg::Key.new(private_armor: 'SECRET', public_armor: 'PUBLIC', key_id: 'ABCDEF0123456789', fingerprint: 'F' * 40)

      refute_includes key.inspect, 'SECRET'
      refute_includes key.to_s, 'SECRET'
      assert_equal '23456789', key.short_id
    end
  end

  describe ::PackmanNova::Gpg::ContainerExecutor do
    it 'runs gpg as the entrypoint with the temporary home mounted' do
      executor = ::PackmanNova::Gpg::ContainerExecutor.new(runner: nil, image: 'img', extra_args: ['--net=none'])
      command = executor.command(['--show-keys', '/gnupg/key.asc'], '/tmp/home')

      assert_equal ['--homedir', '/gnupg', '--show-keys', '/gnupg/key.asc'], command.fetch(:args)
      assert_equal ['--entrypoint', 'gpg', '--net=none'], command.fetch(:extra_args)
      assert_equal ['--mount', 'type=bind,source=/tmp/home,target=/gnupg'], command.fetch(:mounts).first.to_args
      assert_equal '/gnupg/key.asc', executor.path('/tmp/home', 'key.asc')
    end
  end

  describe 'with gpg on the host' do
    subprocess = ::PackmanNova::Utils::Subprocess.new(logger: ::PackmanNova::Logging::Logger.new(outputs: [::StringIO.new]))
    available = ::PackmanNova::Gpg::HostExecutor.available?(subprocess)
    generated = nil

    let(:gpg) { ::PackmanNova::Gpg.new(executor: ::PackmanNova::Gpg::HostExecutor.new(subprocess: subprocess)) }
    let(:key) { generated ||= gpg.generate(name: 'packman-nova unit test', email: 'unit@example.invalid') }

    before { skip 'gpg is not installed' unless available }

    it 'generates an RSA key and reports matching info for both halves' do
      assert_includes key.private_armor, '-----BEGIN PGP PRIVATE KEY BLOCK-----'
      assert_includes key.public_armor, '-----BEGIN PGP PUBLIC KEY BLOCK-----'
      private_info = gpg.info(key.private_base64)
      public_info = gpg.info(key.public_armor)

      assert_predicate private_info, :secret?
      refute_predicate public_info, :secret?
      assert_equal key.fingerprint, public_info.fingerprint
      assert_equal key.key_id, private_info.key_id
      assert_equal ['packman-nova unit test <unit@example.invalid>'], public_info.uids
    end

    it 'derives the public key from the private key' do
      assert_equal key.fingerprint, gpg.info(gpg.public_key_from_private(key.private_armor)).fingerprint
    end

    it 'signs and verifies with the private key' do
      assert gpg.sign_test(key.private_base64)
    end

    it 'fails the sign test with a public key only' do
      assert_raises(::PackmanNova::GpgError) { gpg.sign_test(key.public_armor) }
    end

    it 'rejects garbage keys' do
      assert_raises(::PackmanNova::GpgError) { gpg.info("-----BEGIN PGP PUBLIC KEY BLOCK-----\n\ngarbage\n-----END PGP PUBLIC KEY BLOCK-----\n") }
    end

    it 'rejects multi-line identities' do
      assert_raises(::PackmanNova::GpgError) { gpg.generate(name: "a\nKey-Type: DSA", email: 'x@example.invalid') }
    end
  end
end
