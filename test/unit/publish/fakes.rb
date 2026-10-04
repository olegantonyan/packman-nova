# frozen_string_literal: true

require 'fileutils'

module PublishFakes
  PRIVATE_ARMOR = "-----BEGIN PGP PRIVATE KEY BLOCK-----\n\nZmFrZSBwcml2YXRl\n-----END PGP PRIVATE KEY BLOCK-----\n"
  PUBLIC_ARMOR = "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\nZmFrZSBwdWJsaWM=\n-----END PGP PUBLIC KEY BLOCK-----\n"
  KEY_ID = '31D7469FD4F5F9EF'
  FINGERPRINT = "0EECDB2A7E2B144481F18002#{KEY_ID}".freeze

  class Toolbox
    Status = ::Data.define(:success) do
      def success?
        success
      end
    end

    attr_reader :calls

    def initialize(key_id: KEY_ID, verify: 'OK')
      @key_id = key_id
      @verify = verify
      @calls = []
    end

    def capture(script, mounts:, args: [], env: {})
      calls << [:capture, script, mounts, args, env]
      raise "unexpected capture script: #{script}" unless script == ::PackmanNova::Repo::RpmQuery::SCRIPT

      args.map { |file| "#{file}\t#{query_fields(file)}\n" }.join
    end

    def run(script, mounts:, args: [], env: {})
      calls << [:run, script, mounts, args, env]
      root = mounts.find { |mount| mount.target == ::PackmanNova::Repo::Signer::REPO_MOUNT }.source
      case script
      when ::PackmanNova::Repo::Signer::SCRIPT then sign(root, args)
      when ::PackmanNova::Repo::Createrepo::SCRIPT then createrepo(root, args, env)
      else raise "unexpected run script: #{script}"
      end
    end

    def scripts
      calls.map { |call| call[1] }
    end

    private

    attr_reader :key_id, :verify

    def query_fields(file)
      base = ::File.basename(file)
      name, version, release = base.sub(/\.[^.]+\.rpm\z/, '').match(/\A(.+)-([^-]+)-([^-]+)\z/).captures
      arch = base[/\.([^.]+)\.rpm\z/, 1]
      [name, "#{version}-#{release}", arch, '(none)', '(none)', "summary of #{name}"].join("\t")
    end

    def sign(root, files)
      files.flat_map do |file|
        ::File.write(::File.join(root, file), "signed-by-#{key_id}\n", mode: 'a')
        ["#{file}:\n", "    Header V4 RSA/SHA256 Signature, key ID #{key_id[-8..].downcase}: #{verify}\n", "    Header SHA256 digest: OK\n"]
      end
    end

    def createrepo(root, dirs, env)
      dirs.each do |dir|
        repodata = ::File.join(root, dir, 'repodata')
        ::FileUtils.mkdir_p(repodata)
        ::File.write(::File.join(repodata, 'repomd.xml'), ::Dir.glob('*.rpm', base: ::File.join(root, dir)).sort.join("\n"))
        next if env['SIGN'].to_s.empty?

        ::File.write(::File.join(repodata, 'repomd.xml.asc'), 'signature')
        ::File.write(::File.join(repodata, 'repomd.xml.key'), 'key')
      end
      []
    end
  end

  class Gpg
    def public_key_from_private(_armor)
      PUBLIC_ARMOR
    end

    def info(armor)
      text = ::PackmanNova::Gpg.to_armor(armor)
      ::PackmanNova::Gpg::Info.new(key_id: KEY_ID, fingerprint: FINGERPRINT, uids: ['Test <test@example.invalid>'], secret: text.include?('PRIVATE'))
    end
  end

  class << self
    def key
      ::PackmanNova::Gpg::Key.new(private_armor: PRIVATE_ARMOR, public_armor: PUBLIC_ARMOR, key_id: KEY_ID, fingerprint: FINGERPRINT)
    end

    def manifest(name, enabled: true, kind: 'native')
      Manifest.new(name: name, enabled: enabled, kind: kind)
    end

    def results(dir, packages)
      packages.each do |package, files|
        files.each do |file|
          path = ::File.join(dir, package, file)
          ::FileUtils.mkdir_p(::File.dirname(path))
          ::File.write(path, "#{file} content\n")
        end
      end
    end

    def record(packages, run = 1)
      {
        'schema' => 1, 'run' => run, 'release' => "1699.#{run}.nova.1", 'arch' => 'x86_64', 'tumbleweed_snapshot' => '20260924',
        'started_at' => '2026-09-29T09:00:00Z', 'finished_at' => '2026-09-29T10:00:00Z',
        'packages' => packages.to_h do |name, (code, files)|
          srpm = files.find { |file| file.end_with?('.src.rpm') }
          [name, { 'code' => code, 'rpms' => files - [srpm], 'debuginfo_rpms' => [], 'srpm' => srpm, 'reason' => "#{code} reason", 'built_at' => '2026-09-29T10:00:00Z' }]
        end
      }
    end
  end

  Manifest = ::Data.define(:name, :enabled, :kind) do
    def enabled?
      enabled
    end

    def obs_link?
      kind == 'obs-link'
    end

    def origin
      ::PackmanNova::Manifest::Origin.new(project: 'openSUSE:Factory', package: name, pin: nil)
    end
  end
end
