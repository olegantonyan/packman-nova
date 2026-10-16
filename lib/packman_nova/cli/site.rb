# frozen_string_literal: true

module PackmanNova
  class Cli
    class Site < ::PackmanNova::Cli::Command
      class << self
        def summary
          'regenerate index.html from the repo state of every distro'
        end

        def options(parser, options)
          parser.on('--provider NAME', %w[localfs s3], 'read states from and upload index.html to localfs or s3') { |value| options[:provider] = value }
          parser.on('--output DIR', 'write into DIR instead of the repo root (never uploads)') { |dir| options[:output] = dir }
        end

        def log_file?
          false
        end
      end

      def call
        out.puts(::PackmanNova::Site::Generator.new(config:, states:, logger:).write_index(::PackmanNova::Utils::Path.mkpath(output_dir)))
        provider.publish_root_files!([::PackmanNova::Repo::Layout::INDEX_FILE]) if upload?
        0
      end

      private

      def states
        states = ::PackmanNova::Site::States.new(config:, provider:).call
        raise ::PackmanNova::Error, "no published repo state for any of #{config.distros.join(', ')} under #{provider.root}" if states.values.none?

        states
      end

      def provider
        @provider ||= options[:provider] ? ::PackmanNova::Repo::Providers.build(options[:provider], config:, logger:) : local_provider
      end

      def local_provider
        root = config.repository.provider == 's3' ? config.workdir.repo_mirror_dir : ::PackmanNova::Repo::Layout.localfs_root(config)
        ::PackmanNova::Repo::Providers::Localfs.new(root:, logger:)
      end

      def upload?
        options[:provider] && !options[:output]
      end

      def output_dir
        options[:output] ? ::File.expand_path(options[:output]) : provider.root
      end
    end
  end
end
