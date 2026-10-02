# frozen_string_literal: true

module PackmanNova
  module State
    module Schemas
      VERSION = 1

      SYNC_STATE = {
        file: 'state/sync.json',
        required: %w[schema packages],
        keys: {
          'schema' => 'Integer, currently 1',
          'synced_at' => 'String, ISO 8601 UTC time of the last sync',
          'tumbleweed_snapshot' => 'String, e.g. "20260924", from distro.snapshot_url',
          'factory_prjconf_md5' => 'String, md5 of project/_configs/tumbleweed.conf',
          'local_config_md5' => 'String, md5 of project/_config',
          'rebuild_all_required' => 'Boolean, set when local_config_md5 changed since the last build',
          'packages' => {
            '<name>' => {
              'kind' => 'String, obs-link | native',
              'origin' => 'String, "<project>/<package>" for obs-link, null for native',
              'srcmd5' => 'String, expanded OBS srcmd5 (obs-link) or md5 over the materialized file list (native)',
              'files' => { '<file name>' => 'String, md5 of the materialized file' },
              'synced_at' => 'String, ISO 8601 UTC'
            }
          }
        }
      }.freeze

      BUILD_RECORD = {
        file: 'state/builds/<run>.json, copied to state/last-build.json',
        required: %w[schema run release started_at packages],
        keys: {
          'schema' => 'Integer, currently 1',
          'run' => 'Integer, run counter value',
          'release' => 'String, e.g. "1699.4.nova.1"',
          'image_id' => 'String, builder image id',
          'tumbleweed_snapshot' => 'String',
          'arch' => 'String, e.g. "x86_64"',
          'started_at' => 'String, ISO 8601 UTC',
          'finished_at' => 'String, ISO 8601 UTC, null while running',
          'pbuild_argv' => 'Array of String',
          'packages' => {
            '<name or name:flavor>' => {
              'code' => 'String, pbuild result code: broken succeeded failed unresolvable blocked scheduled waiting building excluded disabled locked',
              'rpms' => 'Array of String, binary rpm file names',
              'srpm' => 'String, src.rpm or nosrc.rpm file name, null if none',
              'duration_sec' => 'Integer, from _log mtime vs start, null if unknown',
              'reason' => 'String, from _reason explain',
              'log' => 'String, path of _log relative to the workdir'
            }
          }
        }
      }.freeze

      REPO_STATE = {
        file: '<repository.path>/state.json on the provider',
        required: %w[schema generated_at run release files packages],
        keys: {
          'schema' => 'Integer, currently 1',
          'generated_at' => 'String, ISO 8601 UTC',
          'run' => 'Integer',
          'release' => 'String',
          'tumbleweed_snapshot' => 'String',
          'key' => { 'id' => 'String, long key id', 'fingerprint' => 'String' },
          'files' => {
            '<arch|src>/<file name>' => { 'sha256' => 'String', 'size' => 'Integer', 'package' => 'String, source package name' }
          },
          'packages' => {
            '<name>' => {
              'kind' => 'String', 'origin' => 'String', 'srcmd5' => 'String', 'version' => 'String', 'release' => 'String',
              'status' => 'String, pbuild code of the last build', 'last_run' => 'Integer', 'built_at' => 'String',
              'reason' => 'String', 'rpms' => 'Array of String', 'srpm' => 'String'
            }
          }
        }
      }.freeze

      ALL = { sync_state: SYNC_STATE, build_record: BUILD_RECORD, repo_state: REPO_STATE }.freeze

      module_function

      def validate!(name, hash)
        schema = ALL.fetch(name) { raise ::ArgumentError, "unknown schema #{name.inspect}" }
        raise ::PackmanNova::Error, "#{schema.fetch(:file)}: expected a JSON object" unless hash.is_a?(::Hash)

        missing = schema.fetch(:required) - hash.keys.map(&:to_s)
        raise ::PackmanNova::Error, "#{schema.fetch(:file)}: missing key(s) #{missing.join(', ')}" unless missing.empty?

        hash
      end
    end
  end
end
