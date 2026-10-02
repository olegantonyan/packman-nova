# frozen_string_literal: true

require 'time'

module PackmanNova
  module Repo
    class StateBuilder
      SUCCEEDED = 'succeeded'

      def initialize(previous:, build_record:, diff:, layout:, manifests:, sync_state: {}, versions: {}, key: nil, now: ::Time.now)
        @previous = previous
        @build_record = build_record
        @build_packages = build_record.fetch('packages', {})
        @diff = diff
        @layout = layout
        @manifests = manifests.to_h { |manifest| [manifest.name, manifest] }
        @sync_packages = sync_state.fetch('packages', {}) || {}
        @versions = versions
        @key = key
        @now = now
      end

      def call
        files = file_entries
        ::PackmanNova::Repo::State.new(header.merge('files' => files, 'packages' => package_entries(files)))
      end

      private

      attr_reader :previous, :build_record, :build_packages, :diff, :layout, :manifests, :sync_packages, :versions, :key, :now

      def header
        {
          'schema' => ::PackmanNova::State::Schemas::VERSION, 'generated_at' => now.utc.iso8601, 'run' => run,
          'release' => build_record['release'] || previous.release, 'tumbleweed_snapshot' => snapshot, 'key' => key_entry
        }
      end

      def run
        [previous.run, build_record['run']].compact.max
      end

      def snapshot
        build_record['tumbleweed_snapshot'] || previous.to_h['tumbleweed_snapshot']
      end

      def key_entry
        key && { 'id' => key.key_id, 'fingerprint' => key.fingerprint }
      end

      def file_entries
        changed = diff.to_stage
        diff.desired.to_h do |relative, entry|
          prior = previous.files[relative]
          [relative, prior && !changed.include?(relative) ? prior : file_entry(relative, entry)]
        end
      end

      def file_entry(relative, entry)
        path = layout.file(relative)
        {
          'sha256' => ::PackmanNova::Utils::Digest.sha256_file(path), 'size' => ::File.size(path), 'package' => entry.package,
          'source_sha256' => entry.source_sha256, 'key_id' => key&.key_id
        }
      end

      def package_entries(files)
        names = (diff.succeeded_packages | diff.retained_packages | tracked_build_packages).sort
        names.to_h { |name| [name, package_entry(name, files)] }
      end

      def tracked_build_packages
        build_packages.keys.select { |name| manifests[base(name)]&.enabled? }
      end

      def package_entry(name, files)
        return built_entry(name, files) if diff.succeeded_packages.include?(name)

        prior = previous.packages[name]
        return failed_entry(name) unless prior

        prior.merge(status_fields(name, prior)).merge(file_fields(name, files))
      end

      def built_entry(name, files)
        record = build_packages.fetch(name)
        identity(name).merge(
          'version' => version_of(name, :version), 'release' => version_of(name, :release),
          'status' => SUCCEEDED, 'last_run' => build_record['run'], 'built_at' => record['built_at'] || build_record['finished_at'],
          'reason' => record['reason']
        ).merge(file_fields(name, files))
      end

      def version_of(name, field)
        info = versions[name]
        return info.public_send(field) if info

        previous.packages.dig(name, field.to_s)
      end

      def failed_entry(name)
        identity(name).merge(
          'version' => nil, 'release' => nil, 'status' => build_packages.dig(name, 'code'), 'last_run' => nil, 'built_at' => nil,
          'reason' => build_packages.dig(name, 'reason'), 'rpms' => [], 'srpm' => nil
        )
      end

      def status_fields(name, prior)
        code = build_packages.dig(name, 'code')
        code ? { 'status' => code, 'reason' => build_packages.dig(name, 'reason') } : { 'status' => prior['status'], 'reason' => prior['reason'] }
      end

      def file_fields(name, files)
        own = files.select { |_relative, entry| entry['package'] == name }.keys.sort
        sources, binaries = own.partition { |relative| ::PackmanNova::Repo::RpmFile.source?(relative) }
        { 'rpms' => binaries, 'srpm' => sources.first }
      end

      def identity(name)
        manifest = manifests[base(name)]
        {
          'kind' => manifest&.kind, 'origin' => manifest&.obs_link? ? manifest.origin.to_s : nil,
          'srcmd5' => sync_packages.dig(base(name), 'srcmd5') || sync_packages.dig(name, 'srcmd5')
        }
      end

      def base(name)
        name.split(':', 2).first
      end
    end
  end
end
