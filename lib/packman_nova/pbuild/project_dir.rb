# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class ProjectDir
      CONTAINER_PATH = '/project'
      BUILD_ROOT_CONTAINER_PATH = '/build-root'
      DIST_CONFIG = '_configs/tumbleweed.conf'
      LOCAL_CONFIG = '_config'

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

      def dist_config
        ::File.join(host_path, DIST_CONFIG)
      end

      def local_config
        ::File.join(host_path, LOCAL_CONFIG)
      end

      def dist_container_path
        ::File.join(CONTAINER_PATH, DIST_CONFIG)
      end

      def results_dir
        workdir.results_dir(reponame: reponame, arch: arch)
      end

      def configs_present?
        [dist_config, local_config].all? { |path| ::File.file?(path) }
      end

      def validate!(selected = [])
        raise ::PackmanNova::BuildError.new("#{host_path}: #{LOCAL_CONFIG} or #{DIST_CONFIG} missing; run sync first", failed_packages: []) unless configs_present?

        unknown = selected.reject { |name| package_names.include?(name.split(':', 2).first) }
        raise ::PackmanNova::BuildError.new("unknown package(s) in #{host_path}: #{unknown.join(', ')}", failed_packages: unknown) unless unknown.empty?

        self
      end

      def package_names
        return [] unless ::File.directory?(host_path)

        ::Dir.children(host_path).reject { |name| name.start_with?('.', '_') }.select { |name| ::File.directory?(::File.join(host_path, name)) }.sort
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
