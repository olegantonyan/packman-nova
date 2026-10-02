# frozen_string_literal: true

module PackmanNova
  class Gpg
    class HostExecutor
      EXECUTABLE = 'gpg'
      GPGCONF = 'gpgconf'

      class << self
        def available?(subprocess)
          subprocess.capture?([EXECUTABLE, '--version']).first
        end
      end

      def initialize(subprocess:)
        @subprocess = subprocess
      end

      def capture(args, home:)
        subprocess.capture([EXECUTABLE, '--homedir', home, *args], env: env(home))
      rescue ::PackmanNova::SubprocessError => e
        raise ::PackmanNova::GpgError, e.message
      end

      def path(home, name)
        ::File.join(home, name)
      end

      def shutdown(home)
        subprocess.capture?([GPGCONF, '--homedir', home, '--kill', 'all'], env: env(home))
      end

      private

      attr_reader :subprocess

      def env(home)
        { 'GNUPGHOME' => home, 'GPG_AGENT_INFO' => '' }
      end
    end
  end
end
