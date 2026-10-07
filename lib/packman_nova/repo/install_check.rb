# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  module Repo
    class InstallCheck
      DISTRO_MOUNT = '/distro'
      REPO_MOUNT = ::PackmanNova::Repo::Signer::REPO_MOUNT
      SCRIPT = 'arch="$1"; shift; installcheck "$arch" "$@" || true'
      PRIMARY = /<data type="primary">.*?<location href="([^"]+)"/m
      CASCADE = /but none of the providers can be installed/

      Problem = ::Data.define(:rpm, :lines) do
        def name = rpm.sub(/-[^-]+-[^-]+\.[^.]+\z/, '')
        def missing = lines.filter_map { |line| line[/\Anothing provides (\S+)/, 1] }.uniq
        def causes = lines.grep_v(CASCADE)
      end

      def initialize(toolbox:, downloader:, workdir:, logger:, allow_missing:)
        @toolbox = toolbox
        @downloader = downloader
        @workdir = workdir
        @logger = logger
        @allow_missing = allow_missing
      end

      def by_package(layout:, arch:, repos:, desired:)
        problems = call(layout:, arch:, repos:)
        problems.each { |problem| logger.error("not installable: #{problem.rpm}: #{problem.causes.join('; ')}") }
        problems.group_by { |problem| desired["#{arch}/#{problem.rpm}.rpm"]&.package }.except(nil).transform_values { |list| summary(list) }
      end

      def call(layout:, arch:, repos:)
        distro = fetch_distro(repos)
        primary = "#{arch}/#{primary_href(::File.read(layout.repomd(arch)))}"
        output = toolbox.capture(SCRIPT, mounts: mounts(layout), args: [arch, "#{REPO_MOUNT}/#{primary}", '--nocheck', *distro])
        parse(output).reject { |problem| allowed?(problem) }
      end

      private

      attr_reader :toolbox, :downloader, :workdir, :logger, :allow_missing

      def distro_dir
        ::File.join(workdir.tmp_dir, 'installcheck')
      end

      def fetch_distro(repos)
        ::FileUtils.rm_rf(distro_dir)
        ::FileUtils.mkdir_p(distro_dir)
        repos.each_with_index.map do |url, index|
          base = url.delete_suffix('/')
          href = primary_href(downloader.get("#{base}/repodata/repomd.xml"))
          name = "#{index}-#{::File.basename(href)}"
          downloader.download("#{base}/#{href}", ::File.join(distro_dir, name))
          "#{DISTRO_MOUNT}/#{name}"
        end
      end

      def primary_href(repomd)
        repomd[PRIMARY, 1] || raise(::PackmanNova::PublishError, 'repomd.xml has no primary metadata')
      end

      def mounts(layout)
        [
          ::PackmanNova::Container::Mount.new(source: layout.repo_dir, target: REPO_MOUNT, readonly: true),
          ::PackmanNova::Container::Mount.new(source: distro_dir, target: DISTRO_MOUNT, readonly: true)
        ]
      end

      def parse(output)
        output.lines.slice_before(/\Acan't install /).filter_map do |block|
          rpm = block.first[/\Acan't install (\S+):/, 1]
          rpm && Problem.new(rpm:, lines: block.drop(1).map(&:strip).reject(&:empty?))
        end
      end

      def summary(problems)
        problems.flat_map { |problem| problem.causes.map { |line| "#{problem.name}: #{line}" } }.uniq
      end

      def allowed?(problem)
        missing = problem.missing
        !missing.empty? && (missing - allow_missing).empty?
      end
    end
  end
end
