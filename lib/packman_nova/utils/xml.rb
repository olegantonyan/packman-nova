# frozen_string_literal: true

require 'rexml/document'

module PackmanNova
  module Utils
    module Xml
      module_function

      def parse(string)
        ::REXML::Document.new(string)
      rescue ::REXML::ParseException => e
        raise ::PackmanNova::Error, "invalid XML: #{e.message.lines.first&.strip}"
      end

      def attributes(node, xpath)
        ::REXML::XPath.match(node, xpath).map { |element| element.attributes.each_with_object({}) { |(name, value), acc| acc[name] = value } }
      end

      def text(node, xpath)
        ::REXML::XPath.first(node, xpath)&.text
      end
    end
  end
end
