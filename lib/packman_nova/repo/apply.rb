# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  module Repo
    class Apply
      def initialize(config:, workdir:, toolbox:)
        @config = config
        @workdir = workdir
        @toolbox = toolbox
      end

      def call(diff:, layout:, arch:, run:, key: nil)
        with_key_dir(key) do |key_dir|
          versions = stager.call(diff: diff, layout: layout, run: run, key: key, key_dir: key_dir)
          diff.to_remove.each { |relative| ::FileUtils.rm_f(layout.file(relative)) }
          refresh_metadata(diff, layout, arch, key_dir)
          versions
        end
      end

      def metadata_dirs(layout, arch)
        sources = config.repository.publish_srpms? || ::File.directory?(layout.src_dir)
        [arch, *(sources ? [::PackmanNova::Repo::Layout::SRC] : [])]
      end

      private

      attr_reader :config, :workdir, :toolbox

      def with_key_dir(key, &)
        return yield(nil) unless key

        workdir.mktmpdir('gpg-') { |dir| yield(::PackmanNova::Repo::Signer.write_key_dir(dir, key)) }
      end

      def stager
        ::PackmanNova::Repo::Stager.new(
          workdir: workdir, rpm_query: ::PackmanNova::Repo::RpmQuery.new(toolbox: toolbox), signer: ::PackmanNova::Repo::Signer.new(toolbox: toolbox)
        )
      end

      def refresh_metadata(diff, layout, arch, key_dir)
        dirs = metadata_dirs(layout, arch)
        return if diff.empty? && dirs.all? { |dir| metadata_current?(layout, dir, key_dir) }

        ::PackmanNova::Repo::Createrepo.new(toolbox: toolbox).call(repo_dir: layout.repo_dir, dirs: dirs, key_dir: key_dir)
      end

      def metadata_current?(layout, dir, key_dir)
        ::File.file?(layout.repomd(dir)) && (key_dir.nil? || ::File.file?("#{layout.repomd(dir)}.asc"))
      end
    end
  end
end
