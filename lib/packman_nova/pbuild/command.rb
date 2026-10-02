# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class Command
      EXECUTABLE = 'pbuild'
      PROJECT = ::PackmanNova::Pbuild::ProjectDir::CONTAINER_PATH

      def initialize(reponame:, arch:, repos:, buildjobs:, jobs:, release:, checks: true, debuginfo: false, baselibs: false,
                     repo_refresh: true, rebuild_packages: [], rebuild: false, single: nil, extra_args: [])
        raise ::PackmanNova::Error, 'use only one of --package, --rebuild and --single' if [rebuild_packages.any?, rebuild, !single.nil?].count(true) > 1

        @settings = {
          reponame: reponame, arch: arch, repos: repos, buildjobs: buildjobs, jobs: jobs, release: release, checks: checks, debuginfo: debuginfo,
          baselibs: baselibs, repo_refresh: repo_refresh, rebuild_packages: rebuild_packages, rebuild: rebuild, single: single, extra_args: extra_args
        }.freeze
        freeze
      end

      %i[reponame arch repos buildjobs jobs release rebuild_packages single extra_args].each do |name|
        define_method(name) { settings.fetch(name) }
      end

      def rebuild?
        settings.fetch(:rebuild)
      end

      def argv
        [
          EXECUTABLE, *target_args, '--root', ::PackmanNova::Pbuild::ProjectDir::BUILD_ROOT_CONTAINER_PATH,
          '--buildjobs', buildjobs.to_s, '--jobs', jobs.to_s, '--release', release, *flag_args, *selection_args, *extra_args, PROJECT
        ]
      end

      def result_argv(details: false)
        [EXECUTABLE, '--reponame', reponame, '--arch', arch, '--result-code', 'all', *(details ? [] : ['--terse']), PROJECT]
      end

      def repoquery_argv(name)
        [EXECUTABLE, *target_args, '--no-repo-refresh', '--repoquery', name, PROJECT]
      end

      private

      attr_reader :settings

      def target_args
        [
          '--dist', ::File.join(PROJECT, ::PackmanNova::Pbuild::ProjectDir::DIST_CONFIG), '--reponame', reponame, '--arch', arch,
          *repos.flat_map { |repo| ['--repo', repo] }
        ]
      end

      def flag_args
        [
          *(settings.fetch(:checks) ? [] : ['--no-checks']),
          *(settings.fetch(:debuginfo) ? ['--debuginfo'] : []),
          *(settings.fetch(:baselibs) ? ['--baselibs'] : []),
          *(settings.fetch(:repo_refresh) ? [] : ['--no-repo-refresh'])
        ]
      end

      def selection_args
        return ['--single', single] if single
        return %w[--rebuild all] if rebuild?

        rebuild_packages.flat_map { |name| ['--rebuild-pkg', name] }
      end
    end
  end
end
