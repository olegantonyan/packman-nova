# frozen_string_literal: true

module PackmanNova
  module Repo
    module UploadOrder
      TEXT = 'text/plain; charset=utf-8'
      CONTENT_TYPES = {
        '.rpm' => 'application/x-rpm', '.xml' => 'application/xml', '.gz' => 'application/gzip', '.zst' => 'application/zstd',
        '.xz' => 'application/x-xz', '.bz2' => 'application/x-bzip2', '.sqlite' => 'application/vnd.sqlite3',
        '.asc' => TEXT, '.key' => TEXT, '.repo' => TEXT, '.json' => 'application/json', '.html' => 'text/html; charset=utf-8',
        '.css' => 'text/css', '.js' => 'text/javascript', '.svg' => 'image/svg+xml'
      }.freeze
      REPOMD_RANKS = { 'repomd.xml' => 2, 'repomd.xml.asc' => 3, 'repomd.xml.key' => 4 }.freeze
      ROOT_RANKS = { 'index.html' => 8, 'packages.json' => 9, 'packman-nova.key' => 10 }.freeze
      OTHER_RANK = 7

      module_function

      def content_type(key)
        CONTENT_TYPES.fetch(::File.extname(key), 'application/octet-stream')
      end

      def sort(keys)
        keys.sort_by { |key| [rank(key), key] }
      end

      def rank(key)
        return 0 if key.end_with?('.rpm')
        return REPOMD_RANKS.fetch(::File.basename(key), 1) if key.include?("/#{::PackmanNova::Repo::Layout::REPODATA}/")
        return 5 if key.end_with?('.repo')
        return 6 if ::File.basename(key) == ::PackmanNova::Repo::Layout::STATE_FILE

        ROOT_RANKS.fetch(key, OTHER_RANK)
      end
    end
  end
end
