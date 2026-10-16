# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  module Repo
    module Providers
      class Base
        attr_reader :root

        def initialize(root:, logger:)
          @root = ::File.expand_path(root)
          @logger = logger
        end

        def remote?
          false
        end

        def prepare!(layout:, dry_run: false)
          ::FileUtils.mkdir_p(layout.repo_dir) unless dry_run
          layout
        end

        def sync!(layout:)
          layout
        end

        def archive_sources!(_archive)
          []
        end

        def fetch(key)
          path = ::File.join(root, key)
          ::File.file?(path) ? path : nil
        end

        def publish_root_files!(keys)
          keys
        end

        private

        attr_reader :logger
      end
    end
  end
end
