# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class Environment
      attr_reader :config, :logger

      def initialize(config:, logger:, subprocess: nil, runtime: nil, image: nil)
        @config = config
        @logger = logger
        @subprocess = subprocess
        @runtime = runtime
        @image = image
      end

      def workdir
        @workdir ||= config.workdir
      end

      def subprocess
        @subprocess ||= ::PackmanNova::Utils::Subprocess.new(logger:)
      end

      def runtime
        @runtime ||= ::PackmanNova::Container::Runtime.detect(config:)
      end

      def image(tag: nil)
        return ::PackmanNova::Container::Image.new(runtime:, config:, logger:, subprocess:, workdir:, tag:) if tag

        @image ||= ::PackmanNova::Container::Image.new(runtime:, config:, logger:, subprocess:, workdir:)
      end

      def runner
        ::PackmanNova::Container::Runner.new(runtime:, logger:, subprocess:)
      end

      def project_dir
        @project_dir ||= ::PackmanNova::Pbuild::ProjectDir.new(workdir:, reponame: config.pbuild.reponame, arch: config.distro.arches.first)
      end

      def baselibs?
        !config.distro.baselibs.arch.empty?
      end

      def baselibs_results_dir
        config.results_dir(config.distro.baselibs.arch)
      end

      def executor(image: self.image.tag)
        ::PackmanNova::Pbuild::Executor.new(config:, runner:, project_dir:, image:)
      end

      def command(release:, baselibs: false, **)
        settings = config.pbuild
        ::PackmanNova::Pbuild::Command.new(
          reponame: settings.reponame, **target(baselibs), release:, buildjobs: settings.buildjobs, jobs: settings.jobs,
          checks: settings.checks?, debuginfo: settings.debuginfo?, baselibs:, repo_refresh: settings.repo_refresh?,
          extra_args: settings.extra_args, **
        )
      end

      def sync_state
        ::PackmanNova::Sync::State.new(workdir:)
      end

      def repo_state_files
        [::PackmanNova::Repo::Layout.localfs_root(config), workdir.repo_mirror_dir].uniq.map do |root|
          ::PackmanNova::Repo::Layout.from_config(config, root:).state_file
        end
      end

      private

      def target(baselibs)
        source = baselibs ? config.distro.baselibs : config.distro
        { arch: baselibs ? source.arch : project_dir.arch, repos: source.repos }
      end
    end
  end
end
