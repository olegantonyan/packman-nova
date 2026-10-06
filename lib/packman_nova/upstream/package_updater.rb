# frozen_string_literal: true

module PackmanNova
  class Upstream
    class PackageUpdater
      BASELIBS = 'baselibs.conf'
      CHECKSUM_KEYS = %w[sha256 size].freeze

      Change = ::Data.define(:old_version, :new_version, :snapshot) do
        def rpm_version
          ::PackmanNova::Upstream::VersionText.rpm(new_version)
        end
      end

      def initialize(manifest:, fetcher:, snapshots:, changes:, logger:)
        @manifest = manifest
        @fetcher = fetcher
        @snapshots = snapshots
        @changes = changes
        @logger = logger
      end

      def call(probe)
        spec = ::PackmanNova::Upstream::SpecFile.new(::File.read(spec_path))
        data = ::PackmanNova::Utils::Yaml.load_file(manifest_path)
        change = change_for(spec, data, probe)
        write(updated_files(spec, update_manifest(data, change), change))
        logger.info("#{manifest.name}: #{spec.version} -> #{change.rpm_version}")
        change.rpm_version
      end

      private

      attr_reader :manifest, :fetcher, :snapshots, :changes, :logger

      def watch
        manifest.watch
      end

      def spec_path
        ::File.join(manifest.dir, manifest.spec_name)
      end

      def manifest_path
        ::File.join(manifest.dir, ::PackmanNova::Manifest::FILE_NAME)
      end

      def changes_path
        spec_path.sub(/\.spec\z/, '.changes')
      end

      def change_for(spec, data, probe)
        snapshot = watch.snapshot? ? snapshots.call(name: manifest.name, watch:, probe:) : nil
        old_version = old_version(spec.version, data.fetch('sources', []))
        Change.new(old_version:, new_version: snapshot&.version || probe.version, snapshot:)
      end

      def old_version(spec_version, sources)
        candidates = [spec_version, spec_version.tr('+', '-')].uniq
        candidates.find { |version| sources.any? { |source| mentions?(source, version) } } || spec_version
      end

      def update_manifest(data, change)
        sources = data.fetch('sources', [])
        ensure_touched!(sources, change)
        text = sources.reduce(::PackmanNova::Upstream::ManifestText.new(::File.read(manifest_path))) do |manifest_text, source|
          updated = update_source(source, change)
          updated == source ? manifest_text : manifest_text.with_source(source, updated)
        end
        (change.snapshot ? text.with_commit(change.snapshot.commit) : text).text
      end

      def ensure_touched!(sources, change)
        return if sources.any? { |source| snapshot_file?(source, change.snapshot) || mentions?(source, change.old_version) }

        raise ::PackmanNova::UpstreamError, "#{manifest.name}: no source in #{manifest_path} mentions #{change.old_version}"
      end

      def update_source(source, change)
        return snapshot_source(source, change.snapshot) if snapshot_file?(source, change.snapshot)
        return source unless mentions?(source, change.old_version)

        renamed = rename(source, change)
        blob = fetch(renamed)
        renamed.merge('sha256' => blob.sha256, 'size' => blob.size)
      end

      def fetch(source)
        fetcher.fetch(::PackmanNova::Manifest::Source.new(file: source['file'], urls: source.fetch('urls', [])), package: manifest.name)
      end

      def snapshot_file?(source, snapshot)
        !snapshot.nil? && watch.file_regexp.match?(source['file'])
      end

      def snapshot_source(source, snapshot)
        source.merge('file' => snapshot.file, 'sha256' => snapshot.blob.sha256, 'size' => snapshot.blob.size)
      end

      def rename(source, change)
        renamed = source.except(*CHECKSUM_KEYS).merge('file' => replace(source['file'], change))
        renamed['urls'] = source['urls'].map { |url| replace(url, change) } if source.key?('urls')
        renamed
      end

      def mentions?(source, version)
        [source['file'], *source['urls']].any? { |text| ::PackmanNova::Upstream::VersionText.mentions?(text.to_s, version) }
      end

      def replace(text, change)
        ::PackmanNova::Upstream::VersionText.replace(text, change.old_version, change.new_version)
      end

      def updated_files(spec, manifest_content, change)
        {
          manifest_path => manifest_content,
          **spec_files(spec.with_version(change.old_version, change.new_version), spec.sover, change.snapshot&.sover),
          changes_path => changes.prepend(read_optional(changes_path), change.rpm_version)
        }
      end

      def read_optional(path)
        ::File.file?(path) ? ::File.read(path) : ''
      end

      def write(files)
        files.each { |path, content| ::PackmanNova::Utils::Path.atomic_write(path, content) }
      end

      def spec_files(spec, old_sover, new_sover)
        return { spec_path => spec.content } if old_sover.nil? || new_sover.nil? || old_sover == new_sover

        logger.info("#{manifest.name}: sover #{old_sover} -> #{new_sover}")
        { spec_path => spec.with_sover(old_sover, new_sover).content, **baselibs(old_sover, new_sover) }
      end

      def baselibs(old_sover, new_sover)
        path = ::File.join(manifest.dir, BASELIBS)
        return {} unless ::File.file?(path)

        { path => ::File.read(path).gsub(/(?<=-)#{::Regexp.escape(old_sover)}(?!\d)/) { new_sover } }
      end
    end
  end
end
