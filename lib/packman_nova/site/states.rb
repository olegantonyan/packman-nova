# frozen_string_literal: true

module PackmanNova
  module Site
    class States
      def initialize(config:, provider:)
        @config = config
        @provider = provider
      end

      def call(own: nil)
        config.siblings.to_h do |sibling|
          id = sibling.distro.id
          [id, own && id == config.distro.id ? own : load(sibling)]
        end
      end

      private

      attr_reader :config, :provider

      def load(sibling)
        path = provider.fetch(::PackmanNova::Repo::Layout.from_config(sibling, root: provider.root).state_key)
        path && ::PackmanNova::Repo::State.load(path).to_h
      end
    end
  end
end
