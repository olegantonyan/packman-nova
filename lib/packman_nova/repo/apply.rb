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
          versions = stage(diff, layout, run, key, key_dir)
          diff.to_remove.each { |relative| ::FileUtils.rm_f(layout.file(relative)) }
          refresh_metadata(diff, layout, arch, key_dir)
          versions
        end
      end

      private

      attr_reader :config, :workdir, :toolbox

      def with_key_dir(key, &)
        return yield(nil) unless key

        workdir.mktmpdir('gpg-') { |dir| yield(::PackmanNova::Repo::Signer.write_key_dir(dir, key)) }
      end

      def stage(diff, layout, run, key, key_dir)
        return {} if diff.to_stage.empty?

        workdir.mktmpdir("stage-#{run}-") do |stage|
          diff.to_stage.each { |relative| copy(source(diff, layout, relative), ::File.join(stage, relative)) }
          infos = query(stage, diff.to_stage)
          sign(stage, diff.to_stage, key, key_dir)
          install_all(stage, diff.to_stage, layout)
          versions(diff, infos)
        end
      end

      def install_all(stage, files, layout)
        files.each { |relative| install(::File.join(stage, relative), layout.file(relative)) }
      end

      def query(stage, files)
        ::PackmanNova::Repo::RpmQuery.new(toolbox:).call(dir: stage, files:)
      end

      def sign(stage, files, key, key_dir)
        ::PackmanNova::Repo::Signer.new(toolbox:).call(dir: stage, files:, key_dir:, key_id: key.key_id) if key
      end

      def source(diff, layout, relative)
        entry = diff.desired.fetch(relative)
        entry.retained? ? layout.file(relative) : entry.source
      end

      def copy(source, target)
        ::FileUtils.mkdir_p(::File.dirname(target))
        ::FileUtils.cp(source, target)
      end

      def install(staged, target)
        ::FileUtils.mkdir_p(::File.dirname(target))
        ::FileUtils.mv(staged, target, force: true)
      end

      def versions(diff, infos)
        diff.fresh.group_by { |relative| diff.desired.fetch(relative).package }.to_h do |package, files|
          representative = files.find { |relative| ::PackmanNova::Repo::RpmFile.source?(relative) } || files.min
          [package, infos.fetch(representative)]
        end
      end

      def refresh_metadata(diff, layout, arch, key_dir)
        dirs = metadata_dirs(layout, arch)
        return if diff.empty? && dirs.all? { |dir| metadata_current?(layout, dir, key_dir) }

        ::PackmanNova::Repo::Createrepo.new(toolbox:).call(repo_dir: layout.repo_dir, dirs:, key_dir:)
      end

      def metadata_dirs(layout, arch)
        sources = config.repository.publish_srpms? || ::File.directory?(layout.src_dir)
        [arch, *(sources ? [::PackmanNova::Repo::Layout::SRC] : [])]
      end

      def metadata_current?(layout, dir, key_dir)
        ::File.file?(layout.repomd(dir)) && (key_dir.nil? || ::File.file?("#{layout.repomd(dir)}.asc"))
      end
    end
  end
end
