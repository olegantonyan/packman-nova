# frozen_string_literal: true

require 'zlib'

module PackmanNova
  module Sources
    class SnapshotRevisions
      PACKAGE = %r{<package type="rpm">.*?</package>}m
      NAME = %r{<name>([^<]+)</name>}
      LOCATION = /<location href="([^"]+)"/
      HEADER_RANGE = /<rpm:header-range start="(\d+)" end="(\d+)"/
      DISTURL = %r{\Aobs://[^/]+/(?<project>[^/]+)/[^/]+/(?<srcmd5>\h{32})-(?<package>[^:/]+)}

      Entry = ::Data.define(:location, :range)

      def initialize(repo:, project:, downloader:, subprocess:, workdir:)
        @repo = repo.delete_suffix('/')
        @project = project
        @downloader = downloader
        @subprocess = subprocess
        @workdir = workdir
      end

      def covers?(origin_project)
        origin_project == project
      end

      def srcmd5(package)
        entry = index[package] || raise(::PackmanNova::SyncError, "#{package}: no src.rpm in #{repo}")
        disturl = disturl(entry)
        match = disturl.match(DISTURL)
        return match[:srcmd5] if match && match[:project] == project && match[:package] == package

        raise ::PackmanNova::SyncError, "#{package}: #{entry.location} DISTURL #{disturl.inspect} is not #{project}/#{package}"
      end

      private

      attr_reader :repo, :project, :downloader, :subprocess, :workdir

      def disturl(entry)
        header = downloader.get_range("#{repo}/#{entry.location}", entry.range)
        ::PackmanNova::Sources::RpmHeader.new(header).disturl.to_s
      end

      def index
        @index ||= primary.scan(PACKAGE).filter_map { |block| entry(block) }.to_h
      end

      def entry(block)
        name = block[NAME, 1]
        location = block[LOCATION, 1]
        first, stop = block.match(HEADER_RANGE)&.captures&.map(&:to_i)
        [name, Entry.new(location:, range: first...stop)] if name && location && first
      end

      def primary
        href = repomd[::PackmanNova::Repo::InstallCheck::PRIMARY, 1] || raise(::PackmanNova::SyncError, "#{repo}: repomd.xml has no primary metadata")
        workdir.mktmpdir('snapshot-') do |dir|
          path = downloader.download("#{repo}/#{href}", ::File.join(dir, ::File.basename(href)))
          decompress(path)
        end
      end

      def repomd
        downloader.get("#{repo}/repodata/repomd.xml")
      end

      def decompress(path)
        return ::Zlib::GzipReader.open(path, &:read) if path.end_with?('.gz')
        return subprocess.capture(['zstd', '-dc', path]) if path.end_with?('.zst')

        ::File.read(path)
      end
    end
  end
end
