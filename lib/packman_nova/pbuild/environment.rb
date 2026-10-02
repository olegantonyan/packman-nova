# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class Environment
      REPO_STATE_FILE = 'state.json'
      SYNC_STATE_FILE = 'sync.json'

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
        @subprocess ||= ::PackmanNova::Utils::Subprocess.new(logger: logger)
      end

      def runtime
        @runtime ||= ::PackmanNova::Container::Runtime.detect(config: config)
      end

      def image(tag: nil)
        return ::PackmanNova::Container::Image.new(runtime: runtime, config: config, logger: logger, subprocess: subprocess, workdir: workdir, tag: tag) if tag

        @image ||= ::PackmanNova::Container::Image.new(runtime: runtime, config: config, logger: logger, subprocess: subprocess, workdir: workdir)
      end

      def runner
        ::PackmanNova::Container::Runner.new(runtime: runtime, logger: logger, subprocess: subprocess)
      end

      def project_dir
        @project_dir ||= ::PackmanNova::Pbuild::ProjectDir.new(workdir: workdir, reponame: config.pbuild.reponame, arch: config.distro.arches.first)
      end

      def executor(image: self.image.tag)
        ::PackmanNova::Pbuild::Executor.new(config: config, runner: runner, project_dir: project_dir, image: image)
      end

      def command(release:, **)
        settings = config.pbuild
        ::PackmanNova::Pbuild::Command.new(
          reponame: settings.reponame, arch: project_dir.arch, repos: config.distro.repos, release: release, buildjobs: settings.buildjobs,
          jobs: settings.jobs, checks: settings.checks?, debuginfo: settings.debuginfo?, baselibs: settings.baselibs?,
          repo_refresh: settings.repo_refresh?, extra_args: settings.extra_args, **
        )
      end

      def sync_state
        ::PackmanNova::Pbuild::SyncState.new(path: workdir.state_file(SYNC_STATE_FILE))
      end

      def repo_state_files
        [repo_root, workdir.repo_mirror_dir].uniq.map { |root| ::File.join(root, config.repository.path, REPO_STATE_FILE) }
      end

      def repo_root
        path = config.repository.localfs.path
        path.empty? ? workdir.repo_dir : ::File.expand_path(path)
      end
    end
  end
end
