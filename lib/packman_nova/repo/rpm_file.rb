# frozen_string_literal: true

module PackmanNova
  module Repo
    module RpmFile
      SOURCE = /\.(?:no)?src\.rpm\z/
      DEBUG = /-debug(?:info|source)-/
      ARCH = /\.([A-Za-z0-9_]+)\.rpm\z/
      NOARCH = 'noarch'

      module_function

      def rpm?(name)
        name.end_with?('.rpm')
      end

      def source?(name)
        SOURCE.match?(name)
      end

      def debug?(name)
        DEBUG.match?(name)
      end

      def arch(name)
        name[ARCH, 1]
      end
    end
  end
end
