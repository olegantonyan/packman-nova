# frozen_string_literal: true

require 'fileutils'
require 'uri'

module PackmanNova
  module Repo
    module Providers
      class S3 < ::PackmanNova::Repo::Providers::Base
        STATE_PREFIX = '_state/'
        REQUIRED_SETTINGS = %i[bucket endpoint access_key_id secret_access_key].freeze
        REPOMD_RANKS = { 'repomd.xml' => 2, 'repomd.xml.asc' => 3, 'repomd.xml.key' => 4 }.freeze
        ROOT_RANKS = { 'index.html' => 8, 'packages.json' => 9, 'packman-nova.key' => 10 }.freeze
        OTHER_RANK = 7

        class << self
          def client(settings)
            require 'aws-sdk-s3'
            ::Aws::S3::Client.new(
              endpoint: settings.endpoint, region: settings.region.to_s.empty? ? 'auto' : settings.region, force_path_style: settings.force_path_style?,
              credentials: ::Aws::Credentials.new(settings.access_key_id, settings.secret_access_key),
              retry_mode: 'adaptive', max_attempts: 10, request_checksum_calculation: 'when_required', response_checksum_validation: 'when_required'
            )
          end

          def build(config:, logger:, client: nil)
            settings = validate!(config.repository.s3)
            bucket = ::PackmanNova::Repo::S3Bucket.new(client: client || self.client(settings), name: settings.bucket, prefix: settings.path_in_bucket)
            new(root: config.workdir.repo_mirror_dir, logger:, bucket:, purger: purger(settings, logger), public_url: config.repository.public_url)
          end

          def configured?(settings)
            missing_settings(settings).empty?
          end

          def validate!(settings)
            missing = missing_settings(settings)
            raise ::PackmanNova::ConfigError, "repository.s3: missing #{missing.join(', ')}" unless missing.empty?

            settings
          end

          def missing_settings(settings)
            REQUIRED_SETTINGS.select { |key| settings.public_send(key).to_s.empty? }
          end

          def purger(settings, logger)
            return if settings.cloudflare_zone_id.empty? || settings.cloudflare_api_token.empty?

            ::PackmanNova::Repo::CloudflarePurge.new(zone_id: settings.cloudflare_zone_id, api_token: settings.cloudflare_api_token, logger:)
          end
        end

        attr_reader :bucket

        def initialize(root:, logger:, bucket:, purger: nil, public_url: '')
          super(root:, logger:)
          @bucket = bucket
          @purger = purger
          @public_url = public_url.to_s
        end

        def remote?
          true
        end

        def prepare!(layout:, dry_run: false)
          ::FileUtils.mkdir_p(root)
          dry_run ? fetch_state(layout) : mirror(layout)
          layout
        end

        def sync!(layout:)
          uploads, deletions = sync_plan(layout)
          logger.info("s3: uploading #{uploads.size} object(s), deleting #{deletions.size} from #{bucket.url}")
          uploads.each { |key| bucket.upload(local(key), key) }
          bucket.delete(deletions)
          purge unless uploads.empty? && deletions.empty?
          layout
        end

        def archive_sources!(archive)
          archive.call(bucket)
        end

        private

        attr_reader :purger, :public_url

        def sync_plan(layout)
          remote = managed_listing(layout)
          uploads = local_keys(layout).reject { |key| current?(key, remote[key]) }
          [uploads.sort_by { |key| [upload_rank(key), key] }, remote.keys.reject { |key| ::File.file?(local(key)) }.sort]
        end

        def upload_rank(key)
          return 0 if key.end_with?('.rpm')
          return REPOMD_RANKS.fetch(::File.basename(key), 1) if key.include?("/#{::PackmanNova::Repo::Layout::REPODATA}/")
          return 5 if key.end_with?('.repo')
          return 6 if ::File.basename(key) == ::PackmanNova::Repo::Layout::STATE_FILE

          ROOT_RANKS.fetch(key, OTHER_RANK)
        end

        def mirror(layout)
          remote = managed_listing(layout)
          stale = remote.keys.reject { |key| current?(key, remote[key]) }
          logger.info("s3: mirroring #{stale.size} of #{remote.size} object(s) into #{root}")
          stale.each { |key| bucket.download(key, local(key)) }
          prune(layout, remote.keys)
        end

        def prune(layout, keys)
          (local_keys(layout) - keys).each { |key| ::FileUtils.rm_f(local(key)) }
        end

        def fetch_state(layout)
          key = layout.state_key
          bucket.exist?(key) ? bucket.download(key, local(key)) : ::FileUtils.rm_f(local(key))
        end

        def managed_listing(layout)
          ::PackmanNova::Repo::Layout::ROOT_FILES.reduce(bucket.list("#{layout.path}/")) { |acc, name| acc.merge(bucket.list(name).slice(name)) }
        end

        def local_keys(layout)
          ::Dir.glob('**/*', base: root).select { |key| ::File.file?(local(key)) && layout.managed?(key) }.sort
        end

        def local(key)
          ::File.join(root, key)
        end

        def current?(key, meta)
          path = local(key)
          return false unless meta && ::File.file?(path) && ::File.size(path) == meta[:size]

          meta[:etag].include?('-') || ::PackmanNova::Utils::Digest.md5_file(path) == meta[:etag]
        end

        def purge
          return if purger.nil? || public_url.empty?

          uri = ::URI.parse(public_url)
          purger.call("#{uri.host}#{uri.path.delete_suffix('/')}")
        end
      end
    end
  end
end
