# frozen_string_literal: true

module PackmanNova
  module Sources
    class ObsClient
      CACHE_EXTENSION = '.xml'
      UNSAFE = /[^A-Za-z0-9._~:@!$&'()*+,;=-]/

      Entry = ::Data.define(:name, :md5, :size)

      Listing = ::Data.define(:srcmd5, :entries) do
        def initialize(srcmd5:, entries:)
          super(srcmd5:, entries: entries.sort_by(&:name).freeze)
        end

        def entry(name)
          entries.find { |candidate| candidate.name == name }
        end
      end

      def initialize(api:, downloader:, workdir:)
        @api = api.chomp('/')
        @downloader = downloader
        @workdir = workdir
      end

      def directory(project:, package:, rev: nil)
        label = "#{project}/#{package}"
        cached = cached_listing(project, package, rev, label) if rev || downloader.offline?
        return cached if cached
        raise ::PackmanNova::SyncError, "#{label}: offline and no cached OBS listing" if downloader.offline?

        xml = downloader.get(directory_url(project:, package:, rev:))
        listing = parse(xml, label)
        store(project, package, xml, [listing.srcmd5, rev])
        listing
      end

      def directory_url(project:, package:, rev: nil)
        "#{package_url(project, package)}#{query([%w[expand 1], (['rev', rev] if rev)])}"
      end

      def file_url(project:, package:, name:, rev:)
        "#{package_url(project, package)}/#{escape(name)}#{query([['rev', rev]])}"
      end

      private

      attr_reader :api, :downloader, :workdir

      def parse(xml, label)
        document = ::PackmanNova::Utils::Xml.parse(xml)
        raise ::PackmanNova::SyncError, "#{label}: #{error_summary(document)}" unless document.root&.name == 'directory'

        srcmd5 = document.root.attributes['srcmd5'].to_s
        raise ::PackmanNova::SyncError, "#{label}: listing has no srcmd5" if srcmd5.empty?

        Listing.new(srcmd5:, entries: ::PackmanNova::Utils::Xml.attributes(document, '/directory/entry').map { |attrs| entry(attrs) })
      end

      def entry(attrs)
        Entry.new(name: attrs.fetch('name'), md5: attrs.fetch('md5'), size: ::Kernel.Integer(attrs.fetch('size')))
      end

      def error_summary(document)
        ::PackmanNova::Utils::Xml.text(document, '/status/summary') || "unexpected response (root element #{document.root&.name.inspect})"
      end

      def package_url(project, package)
        "#{api}/source/#{escape(project)}/#{escape(package)}"
      end

      def escape(segment)
        segment.to_s.gsub(UNSAFE) { |char| char.bytes.map { |byte| format('%%%02X', byte) }.join }
      end

      def query(pairs)
        text = pairs.compact.map { |key, value| "#{key}=#{escape(value)}" }.join('&')
        text.empty? ? '' : "?#{text}"
      end

      def cached_listing(project, package, rev, label)
        path = rev ? cache_path(project, package, rev) : newest_cached(project, package)
        return nil unless path && ::File.file?(path)

        parse(::File.read(path), label)
      end

      def newest_cached(project, package)
        ::Dir.glob(::File.join(workdir.obs_cache_dir(project:, package:), "*#{CACHE_EXTENSION}")).max_by { |path| ::File.mtime(path) }
      end

      def store(project, package, xml, keys)
        keys.compact.uniq.each { |key| ::PackmanNova::Utils::Path.atomic_write(cache_path(project, package, key), xml) }
      end

      def cache_path(project, package, key)
        ::File.join(workdir.obs_cache_dir(project:, package:), "#{key}#{CACHE_EXTENSION}")
      end
    end
  end
end
