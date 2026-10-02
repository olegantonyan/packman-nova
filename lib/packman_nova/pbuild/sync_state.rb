# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class SyncState
      attr_reader :path

      def initialize(path:)
        @path = path
      end

      def data
        @data ||= begin
          value = ::PackmanNova::Utils::JsonFile.read(path, default: {})
          value.is_a?(::Hash) ? value : {}
        end
      end

      def exist?
        ::File.file?(path)
      end

      def rebuild_all_required?
        data['rebuild_all_required'] == true
      end

      def tumbleweed_snapshot
        data['tumbleweed_snapshot']
      end

      def packages
        data.fetch('packages', nil) || {}
      end

      def clear_rebuild_all!
        return unless exist?

        fresh = ::PackmanNova::Utils::JsonFile.read(path, default: {})
        ::PackmanNova::Utils::JsonFile.write(path, fresh.merge('rebuild_all_required' => false))
        @data = nil
      end
    end
  end
end
