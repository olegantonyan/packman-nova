# frozen_string_literal: true

require 'erb'

module PackmanNova
  module Site
    module View
      CLASSES = ::Hash.new { |classes, members| classes[members] = ::Data.define(*members) { include ::ERB::Util } }

      module_function

      def wrap(value)
        case value
        when ::Hash then CLASSES[value.keys.map(&:to_sym)].new(**value.to_h { |key, item| [key.to_sym, wrap(item)] })
        when ::Array then value.map { |item| wrap(item) }
        else value
        end
      end
    end
  end
end
