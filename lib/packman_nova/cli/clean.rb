# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  class Cli
    class Clean < ::PackmanNova::Cli::Command
      TARGETS = %i[build_root results cache].freeze

      class << self
        def summary
          'remove build roots, results or caches'
        end

        def options(parser, options)
          parser.on('--build-root', 'remove build-root/ (subuid-owned, via the container runtime)') { options[:build_root] = true }
          parser.on('--results', 'remove project/_build.*/ results') { options[:results] = true }
          parser.on('--cache', 'remove cache/') { options[:cache] = true }
          parser.on('--all', 'all of the above') { options[:all] = true }
          parser.on('--yes', 'do not ask for confirmation') { options[:yes] = true }
        end
      end

      def initialize(input: $stdin, **)
        super(**)
        @input = input
      end

      def call
        paths = targets.to_h { |target| [target, paths_for(target)] }
        return 0 unless confirmed?(paths.values.flatten)

        workdir.with_lock { paths.each { |target, list| list.each { |path| remove(target, path) } } }
        0
      end

      private

      attr_reader :input

      def targets
        selected = TARGETS.select { |target| options[:all] || options[target] }
        raise ::OptionParser::MissingArgument, 'clean: pass --build-root, --results, --cache or --all' if selected.empty?

        selected
      end

      def environment
        @environment ||= ::PackmanNova::Pbuild::Environment.new(config: config, logger: logger)
      end

      def workdir
        environment.workdir
      end

      def paths_for(target)
        case target
        when :build_root then [workdir.build_root]
        when :results then ::Dir.glob(::File.join(workdir.project_dir, '_build.*'))
        else [workdir.cache_dir]
        end.select { |path| ::File.exist?(path) }
      end

      def confirmed?(paths)
        if paths.empty?
          logger.info('nothing to remove')
          return false
        end
        return true if options[:yes]

        out.print("remove #{paths.join(', ')}? [y/N] ")
        input.gets.to_s.strip.match?(/\Ay(es)?\z/i)
      end

      def remove(target, path)
        logger.info("removing #{path}")
        return ::FileUtils.rm_rf(path) unless target == :build_root

        argv = environment.runtime.remove_tree_argv(path, image: config.container.image)
        status = environment.subprocess.execute(argv)
        raise ::PackmanNova::SubprocessError.new(cli: argv, status: status) unless status.success?
      end
    end
  end
end
