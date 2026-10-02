# frozen_string_literal: true

module PackmanNova
  class Cli
    class Site < ::PackmanNova::Cli::Command
      STATE_FILE = 'state.json'

      class << self
        def summary
          'regenerate index.html and packages.json from the repo state'
        end

        def options(parser, options)
          parser.on('--output DIR', 'write into DIR instead of the repo root') { |dir| options[:output] = dir }
        end

        def log_file?
          false
        end
      end

      def call
        generator = ::PackmanNova::Site::Generator.new(config: config, state: load_state, logger: logger)
        generator.write(::PackmanNova::Utils::Path.mkpath(output_dir)).each { |path| out.puts(path) }
        0
      end

      private

      def load_state
        state = ::PackmanNova::Utils::JsonFile.read(state_file)
        raise ::PackmanNova::Error, "repo state not found: #{state_file} (run publish first or check repository.localfs.path)" unless state

        ::PackmanNova::State::Schemas.validate!(:repo_state, state)
      end

      def state_file
        ::File.join(repo_dir, config.repository.path, STATE_FILE)
      end

      def output_dir
        options[:output] ? ::File.expand_path(options[:output]) : repo_dir
      end

      def repo_dir
        return config.workdir.repo_mirror_dir if config.repository.provider == 's3'

        ::PackmanNova::Site::Model.localfs_root(config)
      end
    end
  end
end
