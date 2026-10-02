# frozen_string_literal: true

module PackmanNova
  module Repo
    module Providers
      class Localfs < ::PackmanNova::Repo::Providers::Base
        class << self
          def root_for(config)
            path = config.repository.localfs.path.to_s.strip
            path.empty? ? config.workdir.repo_dir : ::File.expand_path(path)
          end

          def build(config:, logger:)
            new(root: root_for(config), logger: logger)
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
