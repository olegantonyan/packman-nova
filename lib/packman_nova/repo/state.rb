# frozen_string_literal: true

module PackmanNova
  module Repo
    class State
      VOLATILE_KEYS = %w[generated_at].freeze

      class << self
        def load(path)
          data = ::PackmanNova::Utils::JsonFile.read(path)
          data ? new(::PackmanNova::State::Schemas.validate!(:repo_state, data)) : empty
        end

        def empty
          new(
            'schema' => ::PackmanNova::State::Schemas::VERSION, 'generated_at' => nil, 'run' => nil, 'release' => nil,
            'tumbleweed_snapshot' => nil, 'key' => nil, 'files' => {}, 'packages' => {}
          )
        end
      end

      def initialize(data)
        @data = data
      end

      def files = data.fetch('files') || {}
      def packages = data.fetch('packages') || {}
      def run = data['run']
      def release = data['release']
      def key_id = data.dig('key', 'id')

      def empty?
        files.empty? && packages.empty?
      end

      def files_of(package)
        files.select { |_relative, entry| entry['package'] == package }.keys.sort
      end

      def package_names
        (packages.keys | files.values.map { |entry| entry['package'] }).compact.sort
      end

      def same_content?(other)
        comparable == other.comparable
      end

      def to_h
        data
      end

      def write(path)
        ::PackmanNova::State::Schemas.validate!(:repo_state, data)
        ::PackmanNova::Utils::JsonFile.write(path, data)
      end

      protected

      def comparable
        data.except(*VOLATILE_KEYS)
      end

      private

      attr_reader :data
    end
  end
end
