# frozen_string_literal: true

require 'yaml'

module PackmanNova
  module Utils
    module Yaml
      module_function

      def load(string, symbolize_names: false)
        ::YAML.safe_load(string, permitted_classes: [], aliases: true, symbolize_names: symbolize_names)
      end

      def load_file(path, symbolize_names: false)
        load(::File.read(path), symbolize_names: symbolize_names)
      end
    end
  end
end
