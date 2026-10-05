# frozen_string_literal: true

module PackmanNova
  module Repo
    class Signer
      REPO_MOUNT = '/repo'
      KEY_MOUNT = '/gpgtmp'
      PRIVATE_KEY = 'key.priv'
      PUBLIC_KEY = 'key.pub'
      SCRIPT = <<~SH.freeze
        export GNUPGHOME="$(mktemp -d)"
        gpg --batch --quiet --import #{KEY_MOUNT}/#{PRIVATE_KEY}
        rpm --import #{KEY_MOUNT}/#{PUBLIC_KEY}
        cd #{REPO_MOUNT}
        rpm --define '_signature gpg' --define "_gpg_name $KEY_ID" --addsign "$@"
        rpm -Kv "$@"
      SH

      class << self
        def write_key_dir(dir, key)
          ::File.write(::File.join(dir, PRIVATE_KEY), key.private_armor, perm: 0o600)
          ::File.write(::File.join(dir, PUBLIC_KEY), key.public_armor, perm: 0o644)
          dir
        end

        def mounts(dir:, key_dir:)
          [
            ::PackmanNova::Container::Mount.new(source: dir, target: REPO_MOUNT),
            ::PackmanNova::Container::Mount.new(source: key_dir, target: KEY_MOUNT, readonly: true)
          ]
        end
      end

      def initialize(toolbox:)
        @toolbox = toolbox
      end

      def call(dir:, files:, key_dir:, key_id:)
        return [] if files.empty?

        lines = toolbox.run(SCRIPT, mounts: self.class.mounts(dir:, key_dir:), args: files, env: { 'KEY_ID' => key_id, 'GPG_TTY' => '/dev/null' })
        verify!(lines, files, key_id)
        files
      end

      private

      attr_reader :toolbox

      def verify!(lines, files, key_id)
        report = verification_report(lines)
        short = key_id[-8..].downcase
        bad = files.reject { |file| report.fetch(file, []).any? { |line| line.downcase.include?("key id #{short}: ok") } }
        raise ::PackmanNova::PublishError, "rpm -Kv did not confirm a signature by #{key_id} on: #{bad.join(', ')}" unless bad.empty?
      end

      def verification_report(lines)
        current = nil
        lines.each_with_object({}) do |line, acc|
          if (header = line.match(/\A(\S.*\.rpm):\s*\z/))
            current = header[1]
            acc[current] = []
          elsif current && line.start_with?(' ', "\t")
            acc[current] << line.strip
          end
        end
      end
    end
  end
end
