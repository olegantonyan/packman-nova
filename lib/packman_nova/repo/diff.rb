# frozen_string_literal: true

module PackmanNova
  module Repo
    class Diff
      Result = ::Data.define(:desired, :to_add, :to_replace, :to_remove, :to_resign, :retained_packages, :succeeded_packages, :ignored) do
        def empty?
          [to_add, to_replace, to_remove, to_resign].all?(&:empty?)
        end

        def to_stage
          to_add + to_replace + to_resign
        end

        def fresh
          to_add + to_replace
        end
      end

      def initialize(build_record:, results_dir:, state:, enabled:, arch:, repo_dir:, baselibs_dir: nil, publish_srpms: true, publish_debuginfo: false, key_id: nil,
                     check_files: true)
        @outputs = ::PackmanNova::Repo::BuildOutputs.new(
          build_record: build_record, results_dir: results_dir, baselibs_dir: baselibs_dir, enabled: enabled, arch: arch,
          publish_srpms: publish_srpms, publish_debuginfo: publish_debuginfo
        )
        @retention = ::PackmanNova::Repo::Retention.new(state: state, build_record: build_record, enabled: enabled)
        @state = state
        @arch = arch
        @repo_dir = repo_dir
        @key_id = key_id
        @check_files = check_files
      end

      def call
        built = outputs.entries
        retained = retained_entries.reject { |relative, _entry| built.key?(relative) }
        desired = retained.merge(built).sort.to_h
        Result.new(desired: desired, **compare(built, retained), to_remove: removals(desired), **packages)
      end

      private

      attr_reader :outputs, :retention, :state, :arch, :repo_dir, :key_id, :check_files

      def packages
        { retained_packages: retention.packages, succeeded_packages: outputs.packages, ignored: outputs.ignored.sort }
      end

      def published
        @published ||= state.files.select { |relative, _entry| in_scope?(relative) }
      end

      def retained_entries
        retention.files.each_with_object({}) do |(relative, entry), acc|
          next unless in_scope?(relative)
          next outputs.ignored << "#{relative}: retained for #{entry['package']} but missing on disk" if missing?(relative)

          acc[relative] = ::PackmanNova::Repo::BuildOutputs::Entry.new(relative: relative, package: entry['package'], source: nil, source_sha256: source_sha256(entry))
        end
      end

      def compare(built, retained)
        lists = { to_add: [], to_replace: [], to_resign: [] }
        built.each_value { |entry| (list = classify(entry, published[entry.relative])) && (lists[list] << entry.relative) }
        retained.each_key { |relative| lists[:to_resign] << relative if resign?(published[relative]) }
        lists.transform_values(&:sort)
      end

      def classify(entry, previous)
        return :to_add if previous.nil? || missing?(entry.relative)
        return :to_replace if source_sha256(previous) != entry.source_sha256

        :to_resign if resign?(previous)
      end

      def source_sha256(entry)
        entry['source_sha256'] || entry['sha256']
      end

      def resign?(previous)
        !key_id.nil? && !previous.nil? && previous['key_id'] != key_id
      end

      def missing?(relative)
        check_files && !::File.file?(::File.join(repo_dir, relative))
      end

      def removals(desired)
        (published.keys | untracked).reject { |relative| desired.key?(relative) }.sort
      end

      def untracked
        return [] unless check_files

        [arch, ::PackmanNova::Repo::Layout::SRC].flat_map do |subdir|
          ::Dir.glob('*.rpm', base: ::File.join(repo_dir, subdir)).map { |name| "#{subdir}/#{name}" }
        end
      end

      def in_scope?(relative)
        relative.start_with?("#{arch}/", "#{::PackmanNova::Repo::Layout::SRC}/")
      end
    end
  end
end
