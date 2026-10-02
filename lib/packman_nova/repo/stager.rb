# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  module Repo
    class Stager
      def initialize(workdir:, rpm_query:, signer:)
        @workdir = workdir
        @rpm_query = rpm_query
        @signer = signer
      end

      def call(diff:, layout:, run:, key: nil, key_dir: nil)
        return {} if diff.to_stage.empty?

        workdir.mktmpdir("stage-#{run}-") do |stage|
          infos = stage!(diff, layout, stage)
          signer.call(dir: stage, files: diff.to_stage, key_dir: key_dir, key_id: key.key_id) if key
          diff.to_stage.each { |relative| install(::File.join(stage, relative), layout.file(relative)) }
          versions(diff, infos)
        end
      end

      private

      attr_reader :workdir, :rpm_query, :signer

      def stage!(diff, layout, stage)
        diff.to_stage.each { |relative| copy(source(diff, layout, relative), ::File.join(stage, relative)) }
        rpm_query.call(dir: stage, files: diff.to_stage)
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
    end
  end
end
