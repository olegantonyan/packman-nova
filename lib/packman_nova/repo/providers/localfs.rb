# frozen_string_literal: true

module PackmanNova
  module Repo
    module Providers
      class Localfs < ::PackmanNova::Repo::Providers::Base
        class << self
          def build(config:, logger:)
            new(root: ::PackmanNova::Repo::Layout.localfs_root(config), logger:)
          end
        end

        def sync!(layout:)
          logger.info("localfs: repository is in place at #{root}")
          layout
        end
      end
    end
  end
end
