# frozen_string_literal: true

module PackmanNova
  module Sources
    Listing = ::Data.define(:srcmd5, :entries) do
      class << self
        def parse(xml, label:)
          document = ::PackmanNova::Utils::Xml.parse(xml)
          root = document.root
          raise ::PackmanNova::SyncError, "#{label}: #{error_summary(document)}" unless root&.name == 'directory'

          srcmd5 = root.attributes['srcmd5'].to_s
          raise ::PackmanNova::SyncError, "#{label}: listing has no srcmd5" if srcmd5.empty?

          new(srcmd5: srcmd5, entries: ::PackmanNova::Utils::Xml.attributes(document, '/directory/entry').map { |attrs| entry_from(attrs) })
        end

        def entry_from(attrs)
          ::PackmanNova::Sources::Listing::Entry.new(name: attrs.fetch('name'), md5: attrs.fetch('md5'), size: ::Kernel.Integer(attrs.fetch('size')))
        end

        def error_summary(document)
          summary = ::PackmanNova::Utils::Xml.text(document, '/status/summary')
          summary || "unexpected response (root element #{document.root&.name.inspect})"
        end
      end

      def initialize(srcmd5:, entries:)
        super(srcmd5: srcmd5, entries: entries.sort_by(&:name).freeze)
      end

      def entry(name)
        entries.find { |candidate| candidate.name == name }
      end

      def names
        entries.map(&:name)
      end
    end

    Listing::Entry = ::Data.define(:name, :md5, :size)
  end
end
