# frozen_string_literal: true

require 'uri'

module PackmanNova
  module Sources
    class MirrorIndex
      HREF = /href="([^"?#]+\.src\.rpm)"/i
      Candidate = ::Data.define(:url, :file_name, :version, :release)

      class << self
        def parse(html, base_url:)
          base = base_url.end_with?('/') ? base_url : "#{base_url}/"
          names = html.scan(HREF).flatten.map { |href| ::URI.decode_uri_component(::File.basename(href)) }.uniq
          new(base_url: base, file_names: names)
        end

        def newest(candidates)
          candidates.max_by { |candidate| [::PackmanNova::Sources::RpmVersion.new(candidate.version), ::PackmanNova::Sources::RpmVersion.new(candidate.release)] }
        end
      end

      attr_reader :base_url, :file_names

      def initialize(base_url:, file_names:)
        @base_url = base_url
        @file_names = file_names.freeze
        freeze
      end

      def candidates(package)
        pattern = /\A#{::Regexp.escape(package)}-([^-]+)-([^-]+)\.src\.rpm\z/
        file_names.filter_map do |name|
          match = pattern.match(name)
          next unless match

          Candidate.new(url: base_url + ::PackmanNova::Sources::UrlSegment.escape(name), file_name: name, version: match[1], release: match[2])
        end
      end
    end
  end
end
