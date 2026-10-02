# frozen_string_literal: true

module PackmanNova
  module Pbuild
    module Reason
      SHORT_MD5 = 8

      module_function

      def read(path)
        ::File.file?(path) ? parse(::File.read(path)) : nil
      rescue ::PackmanNova::Error
        nil
      end

      def parse(xml)
        doc = ::PackmanNova::Utils::Xml.parse(xml)
        explain = ::PackmanNova::Utils::Xml.text(doc, '/reason/explain').to_s.strip
        return nil if explain.empty?

        [explain, details(doc)].compact.join(': ')
      end

      def details(doc)
        oldsource = ::PackmanNova::Utils::Xml.text(doc, '/reason/oldsource')
        return "old source #{oldsource[0, SHORT_MD5]}" if oldsource

        changes = ::PackmanNova::Utils::Xml.attributes(doc, '/reason/packagechange').map { |change| "#{change['key']} (#{change['change']})" }
        changes.empty? ? nil : changes.join(', ')
      end
    end
  end
end
