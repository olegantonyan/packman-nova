# frozen_string_literal: true

require 'json'

module PackmanNova
  module Utils
    module JsonFile
      module_function

      def read(path, default: nil)
        return default unless ::File.file?(path)

        ::JSON.parse(::File.read(path))
      rescue ::JSON::ParserError => e
        raise ::PackmanNova::Error, "#{path}: invalid JSON: #{e.message}"
      end

      def write(path, hash)
        ::PackmanNova::Utils::Path.atomic_write(path, "#{::JSON.pretty_generate(hash)}\n")
      end
    end
  end
end
