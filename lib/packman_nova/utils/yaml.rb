# frozen_string_literal: true

require 'yaml'

module PackmanNova
  module Utils
    module Yaml
      module_function

      def load_file(path, symbolize_names: false)
        ::YAML.safe_load_file(path, permitted_classes: [], aliases: true, symbolize_names:)
      end
    end
  end
end
