# frozen_string_literal: true

module PackmanNova
  class Gpg
    class ContainerExecutor
      HOME = '/gnupg'
      ENTRYPOINT = 'gpg'

      class << self
        def build(config:, logger:, subprocess:)
          runner = ::PackmanNova::Container::Runner.from_config(config:, logger:, subprocess:)
          new(runner:, image: config.container.image, extra_args: config.container.extra_args)
        end
      end

      def initialize(runner:, image:, extra_args: [])
        @runner = runner
        @image = image
        @extra_args = extra_args
      end

      def capture(args, home:)
        runner.capture(**command(args, home))
      rescue ::PackmanNova::SubprocessError => e
        raise ::PackmanNova::GpgError, e.message
      end

      def command(args, home)
        {
          image:, args: ['--homedir', HOME, *args], env: { 'GNUPGHOME' => HOME },
          mounts: [::PackmanNova::Container::Mount.new(source: home, target: HOME)],
          extra_args: ['--entrypoint', ENTRYPOINT, *extra_args]
        }
      end

      def path(_home, name)
        ::File.join(HOME, name)
      end

      def shutdown(_home); end

      private

      attr_reader :runner, :image, :extra_args
    end
  end
end
