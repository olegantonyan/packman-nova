# frozen_string_literal: true

module PackmanNova
  module Repo
    class BuildOutputs
      SUCCEEDED = ::PackmanNova::Pbuild::ResultParser::SUCCEEDED

      Entry = ::Data.define(:relative, :package, :source, :source_sha256) do
        def retained?
          source.nil?
        end
      end

      attr_reader :ignored

      def initialize(build_record:, results_dir:, enabled:, arch:, baselibs_dir: nil, publish_srpms: true, publish_debuginfo: false)
        @build_packages = build_record.fetch('packages', {})
        @results_dir = results_dir
        @baselibs_dir = baselibs_dir
        @enabled = enabled
        @arch = arch
        @publish_srpms = publish_srpms
        @publish_debuginfo = publish_debuginfo
        @ignored = []
      end

      def packages
        @packages ||= succeeded_names.select { |name| enabled?(name) }
      end

      def retained?(name)
        enabled?(name) && build_packages.dig(name, 'code') != SUCCEEDED
      end

      def entries
        @entries ||= packages.each_with_object({}) do |name, acc|
          outputs(name).each do |path|
            relative = target(::File.basename(path))
            next unless relative

            claim!(acc, relative, name)
            acc[relative] = Entry.new(relative:, package: name, source: path, source_sha256: ::PackmanNova::Utils::Digest.sha256_file(path))
          end
        end
      end

      private

      attr_reader :build_packages, :results_dir, :baselibs_dir, :enabled, :arch, :publish_srpms, :publish_debuginfo

      def succeeded_names
        names = build_packages.select { |_name, entry| entry['code'] == SUCCEEDED }.keys.sort
        names.reject { |name| enabled?(name) }.each { |name| ignored << "#{name}: succeeded but not enabled" }
        names
      end

      def enabled?(name)
        enabled.include?(::PackmanNova::Manifest.base_name(name))
      end

      def claim!(acc, relative, name)
        owner = acc[relative]&.package
        raise ::PackmanNova::PublishError, "#{relative} is produced by both #{owner} and #{name}" if owner && owner != name
      end

      def outputs(name)
        entry = build_packages.fetch(name)
        files = [*entry['rpms'], *(publish_debuginfo ? entry['debuginfo_rpms'] : []), entry['srpm']].compact.uniq
        files.map { |file| resolve(name, file, results_dir) } + baselibs_outputs(name, entry)
      end

      def baselibs_outputs(name, entry)
        entry.dig('baselibs', 'rpms').to_a.map { |file| resolve(name, file, baselibs_dir) }
      end

      def resolve(name, file, dir)
        return file if file.start_with?('/') && ::File.file?(file)

        candidates = dir ? [::File.join(dir, name, file), ::File.join(dir, file)] : []
        candidates.find { |path| ::File.file?(path) } || raise(::PackmanNova::PublishError, "#{name}: build output #{file} not found under #{dir.inspect}")
      end

      def target(basename)
        return unless ::PackmanNova::Repo::RpmFile.rpm?(basename)
        return source_target(basename) if ::PackmanNova::Repo::RpmFile.source?(basename)
        return if ::PackmanNova::Repo::RpmFile.debug?(basename) && !publish_debuginfo

        file_arch = ::PackmanNova::Repo::RpmFile.arch(basename)
        return "#{arch}/#{basename}" if [arch, ::PackmanNova::Repo::RpmFile::NOARCH].include?(file_arch)

        ignored << "#{basename}: arch #{file_arch} is not published into #{arch}/"
        nil
      end

      def source_target(basename)
        "#{::PackmanNova::Repo::Layout::SRC}/#{basename}" if publish_srpms
      end
    end
  end
end
