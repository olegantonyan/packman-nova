# frozen_string_literal: true

module PackmanNova
  class Cli
    class Build < ::PackmanNova::Cli::Command
      BUILD_OPTIONS = %i[packages rebuild single buildjobs jobs checks debuginfo release sync dry_run].freeze

      class << self
        def summary
          'sync, then run pbuild in the builder container'
        end

        def options(parser, options)
          selection_options(parser, options)
          pbuild_options(parser, options)
        end

        def selection_options(parser, options)
          parser.on('--package NAME', 'rebuild this package (pbuild --rebuild-pkg, repeatable)') { |name| (options[:packages] ||= []) << name }
          parser.on('--rebuild', 'rebuild everything') { options[:rebuild] = true }
          parser.on('--single NAME', 'build only this package (pbuild --single)') { |name| options[:single] = name }
          parser.on('--[no-]sync', 'run sync first (default: yes)') { |value| options[:sync] = value }
          parser.on('--dry-run', 'print the pbuild command only') { options[:dry_run] = true }
          parser.on('--release STR', 'use this release string, do not bump the run counter') { |value| options[:release] = value }
        end

        def pbuild_options(parser, options)
          parser.on('--buildjobs N', ::Integer, 'parallel builds (default: pbuild.buildjobs)') { |value| options[:buildjobs] = value }
          parser.on('--jobs N', ::Integer, 'make jobs per build (default: pbuild.jobs)') { |value| options[:jobs] = value }
          parser.on('--[no-]checks', 'run post-build checks (default: pbuild.checks)') { |value| options[:checks] = value }
          parser.on('--debuginfo', 'build debuginfo packages') { options[:debuginfo] = true }
          parser.on('--[no-]repo-refresh', 'refresh remote repo metadata (default: pbuild.repo_refresh)') { |value| options[:repo_refresh] = value }
        end
      end

      def call
        arguments = options.slice(*BUILD_OPTIONS)
        arguments[:no_repo_refresh] = !options[:repo_refresh] if options.key?(:repo_refresh)
        ::PackmanNova::Build.new(config: config, logger: logger, out: out).call(**arguments)
      end
    end
  end
end
