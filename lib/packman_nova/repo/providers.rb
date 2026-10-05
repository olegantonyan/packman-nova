# frozen_string_literal: true

module PackmanNova
  module Repo
    module Providers
      NAMES = %w[localfs s3].freeze

      module_function

      def build(name, config:, logger:)
        case name
        when 'localfs' then ::PackmanNova::Repo::Providers::Localfs.build(config:, logger:)
        when 's3' then ::PackmanNova::Repo::Providers::S3.build(config:, logger:)
        else raise ::PackmanNova::ConfigError, "unknown repository provider #{name.inspect} (#{NAMES.join(' or ')})"
        end
      end
    end
  end
end
