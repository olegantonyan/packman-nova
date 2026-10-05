# frozen_string_literal: true

module PackmanNova
  module Sources
    class Archive
      PREFIX = '_sources/sha256/'

      class << self
        def key(sha256)
          "#{PREFIX}#{sha256}"
        end

        def from_config(config)
          url = config.repository.public_url.to_s.strip.delete_suffix('/')
          new(base_url: url.match?(%r{\Ahttps?://}i) ? url : nil)
        end
      end

      attr_reader :base_url

      def initialize(base_url:)
        @base_url = base_url
      end

      def url(sha256)
        base_url && sha256 && "#{base_url}/#{self.class.key(sha256)}"
      end
    end
  end
end
