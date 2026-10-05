# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class ProjectDir
      CONTAINER_PATH = '/project'
      BUILD_ROOT_CONTAINER_PATH = '/build-root'

      attr_reader :reponame, :arch

      def initialize(workdir:, reponame:, arch:)
        @workdir = workdir
        @reponame = reponame
        @arch = arch
      end

      def host_path
        workdir.project_dir
      end

      def build_root
        workdir.build_root
      end

      def results_dir
        workdir.results_dir(reponame:, arch:)
      end

      def configs_present?
        [workdir.dist_config_file(reponame), workdir.config_file].all? { |path| ::File.file?(path) }
      end

      def validate!(selected = [])
        raise ::PackmanNova::BuildError, "#{host_path}: _config or #{::PackmanNova::Workdir.dist_config(reponame)} missing; run sync first" unless configs_present?

        unknown = selected.reject { |name| package_names.include?(::PackmanNova::Manifest.base_name(name)) }
        raise ::PackmanNova::BuildError, "unknown package(s) in #{host_path}: #{unknown.join(', ')}" unless unknown.empty?

        self
      end

      def package_names
        workdir.package_names
      end

      def mounts
        [
          ::PackmanNova::Container::Mount.new(source: host_path, target: CONTAINER_PATH),
          ::PackmanNova::Container::Mount.new(source: build_root, target: BUILD_ROOT_CONTAINER_PATH)
        ]
      end

      def prepare!
        [host_path, build_root].each { |path| ::FileUtils.mkdir_p(path) }
        self
      end

      private

      attr_reader :workdir
    end
  end
end
