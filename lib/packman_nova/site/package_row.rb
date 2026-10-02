# frozen_string_literal: true

module PackmanNova
  module Site
    class PackageRow
      OBS_PACKAGE_URL = 'https://build.opensuse.org/package/show/%<project>s/%<package>s'
      ENTRY_KEYS = %w[kind origin srcmd5 version release last_run reason].freeze
      SUCCEEDED = 'succeeded'
      STATUS_CLASSES = { SUCCEEDED => 'ok', 'failed' => 'fail', 'unresolvable' => 'fail', 'broken' => 'fail' }.freeze
      SOURCE_PREFIX = 'src/'

      def initialize(name:, entry:, files:, repo_url:)
        @name = name
        @entry = entry
        @files = files
        @repo_url = repo_url
      end

      def to_h
        ENTRY_KEYS.to_h { |key| [key, entry[key]] }.merge(identity, build)
      end

      private

      attr_reader :name, :entry, :files, :repo_url

      def identity
        { 'name' => name, 'anchor' => ::PackmanNova::Site::Format.anchor(name), 'evr' => evr, 'origin_url' => origin_url }
      end

      def build
        {
          'status' => status, 'status_class' => STATUS_CLASSES.fetch(status, 'other'),
          'built_at' => ::PackmanNova::Site::Format.time(entry['built_at']), 'built_at_iso' => entry['built_at'],
          'files' => file_rows, 'retained' => status != SUCCEEDED && !file_rows.empty?
        }
      end

      def status
        entry['status'].to_s.empty? ? 'unknown' : entry['status']
      end

      def evr
        parts = entry.values_at('version', 'release').map(&:to_s).reject(&:empty?)
        parts.empty? ? nil : parts.join('-')
      end

      def origin_url
        project, package = entry['origin'].to_s.split('/', 2)
        return nil unless entry['kind'] == 'obs-link' && package && !package.empty?

        format(OBS_PACKAGE_URL, project: project, package: package)
      end

      def file_rows
        @file_rows ||= files.select { |path, meta| owned?(path, meta) }
                            .sort_by { |path, _meta| [path.start_with?(SOURCE_PREFIX) ? 1 : 0, path] }
                            .map { |path, meta| file_row(path, meta) }
      end

      def owned?(path, meta)
        meta['package'] == name || listed_names.include?(::File.basename(path))
      end

      def listed_names
        @listed_names ||= [*entry['rpms'], entry['srpm']].compact.map { |file| ::File.basename(file) }
      end

      def file_row(path, meta)
        { 'path' => path, 'name' => ::File.basename(path), 'url' => "#{repo_url}/#{path}", 'size' => ::PackmanNova::Site::Format.size(meta['size']) }
      end
    end
  end
end
