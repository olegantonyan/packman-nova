# frozen_string_literal: true

require 'packman_nova/sources/downloader'
require 'packman_nova/sources/download_cache'
require 'packman_nova/sources/obs_client'
require 'packman_nova/sources/archive'

require 'packman_nova/sync/expected_file'
require 'packman_nova/sync/package_dir'
require 'packman_nova/sync/outcome'
require 'packman_nova/sync/source_fetcher'
require 'packman_nova/sync/public_key'
require 'packman_nova/sync/services'
require 'packman_nova/sync/obs_link_materializer'
require 'packman_nova/sync/native_materializer'
require 'packman_nova/sync/prjconf'
require 'packman_nova/sync/state'
require 'packman_nova/sync/report'
require 'packman_nova/sync/checksum_updater'
require 'packman_nova/sync/run'

module PackmanNova
  class Sync
    def initialize(config:, logger:, services: nil, packages_dir: nil)
      @config = config
      @logger = logger
      @workdir = config.workdir
      @services = services
      @packages_dir = packages_dir || config.packages_dir
    end

    def call(packages: nil, check_only: false, update_checksums: false, prjconf: true)
      options = { packages:, check_only:, update_checksums:, prjconf: }
      return perform(options) if check_only

      workdir.with_lock do
        workdir.prepare!
        perform(options)
      end
    end

    private

    attr_reader :config, :logger, :workdir, :packages_dir

    def perform(options)
      manifests = select_manifests(options)
      run = ::PackmanNova::Sync::Run.new(config:, logger:, workdir:, services:, manifests:, options:)
      report, next_state = run.call(state.load)
      state.save(next_state) unless options.fetch(:check_only)
      report
    end

    def select_manifests(options)
      loader = ::PackmanNova::Manifest::Loader.new(packages_dir:, require_checksums: !options.fetch(:update_checksums))
      names = options[:packages]
      names ? names.uniq.map { |name| loader.find(name) } : loader.all
    end

    def services
      @services ||= ::PackmanNova::Sync::Services.from_config(config:, logger:, workdir:)
    end

    def state
      @state ||= ::PackmanNova::Sync::State.new(workdir:)
    end
  end
end
