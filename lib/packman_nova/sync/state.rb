# frozen_string_literal: true

module PackmanNova
  class Sync
    class State
      FILE_NAME = 'sync.json'

      class << self
        def empty
          { 'schema' => ::PackmanNova::State::Schemas::VERSION, 'packages' => {} }
        end
      end

      def initialize(workdir:)
        @workdir = workdir
      end

      def path
        workdir.state_file(FILE_NAME)
      end

      def load
        data = ::PackmanNova::Utils::JsonFile.read(path, default: nil) || self.class.empty
        ::PackmanNova::State::Schemas.validate!(:sync_state, data)
      end

      def save(data)
        ::PackmanNova::State::Schemas.validate!(:sync_state, data)
        ::PackmanNova::Utils::JsonFile.write(path, data)
      end

      private

      attr_reader :workdir
    end
  end
end
