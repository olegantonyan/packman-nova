# frozen_string_literal: true

module PackmanNova
  module Site
    class Model
      KEY_FILE_NAME = ::PackmanNova::Repo::Layout::PUBLIC_KEY_FILE
      REPO_FILE_NAME = ::PackmanNova::Repo::Layout::REPO_FILE
      SOURCE_DIR = 'src'
      SUCCEEDED = ::PackmanNova::Site::PackageRow::SUCCEEDED
      GITHUB_REPO = %r{\Ahttps://github\.com/([^/]+/[^/]+?)/?\z}
      WORKFLOW_FILE = 'build-publish.yml'

      class << self
        def localfs_root(config)
          path = config.repository.localfs.path
          path.empty? ? config.workdir.repo_dir : ::File.expand_path(path)
        end
      end

      def initialize(config:, state:)
        @config = config
        @state = state
      end

      def public_url
        url = config.repository.public_url.strip.sub(%r{/+\z}, '')
        url.empty? ? "file://#{self.class.localfs_root(config)}" : url
      end

      def repo_url
        "#{public_url}/#{config.repository.path.delete_prefix('/').delete_suffix('/')}"
      end

      def repo_file_url
        "#{repo_url}/#{REPO_FILE_NAME}"
      end

      def key_url
        "#{public_url}/#{KEY_FILE_NAME}"
      end

      def slug
        config.repository.slug
      end

      def commands
        [
          command('add', 'Add the repo', "sudo zypper ar -f -p #{::PackmanNova::Repo::RepoFile::PRIORITY} #{repo_file_url}"),
          command('refresh', 'Import the key', 'sudo zypper --gpg-auto-import-keys ref'),
          command('switch', 'Switch packages', "sudo zypper dup --from #{slug} --allow-vendor-change")
        ]
      end

      def key
        key = state['key']
        return nil unless key.is_a?(::Hash) && key.values_at('id', 'fingerprint').any? { |value| !value.to_s.empty? }

        { 'id' => ::PackmanNova::Site::Format.hex_groups(key['id']), 'fingerprint' => ::PackmanNova::Site::Format.hex_groups(key['fingerprint']) }
      end

      def baseurls
        dirs = config.distro.arches + (config.repository.publish_srpms? ? [SOURCE_DIR] : [])
        dirs.map { |dir| { 'arch' => dir, 'url' => "#{repo_url}/#{dir}" } }
      end

      def packages
        @packages ||= state.fetch('packages', {}).sort_by { |name, _entry| name }.map do |name, entry|
          ::PackmanNova::Site::PackageRow.new(name: name, entry: entry, files: files, repo_url: repo_url).to_h
        end
      end

      def totals
        succeeded = packages.count { |row| row['status'] == SUCCEEDED }
        { 'packages' => packages.size, 'succeeded' => succeeded, 'not_succeeded' => packages.size - succeeded }.merge(file_totals)
      end

      def source_url
        url = config.site.source_url
        url.empty? ? nil : url
      end

      def pipeline_api_url
        repo = GITHUB_REPO.match(source_url.to_s)&.captures&.first
        "https://api.github.com/repos/#{repo}/actions/workflows/#{WORKFLOW_FILE}/runs?per_page=1" if repo
      end

      def to_h
        links.merge(summary).merge(
          'commands' => commands, 'key' => key, 'baseurls' => baseurls, 'totals' => totals, 'packages' => packages
        )
      end

      private

      attr_reader :config, :state

      def files
        state.fetch('files', {})
      end

      def file_totals
        sources = files.keys.count { |path| path.start_with?("#{SOURCE_DIR}/") }
        size = files.values.sum { |meta| meta['size'].to_i }
        { 'binary_rpms' => files.size - sources, 'source_rpms' => sources, 'size' => ::PackmanNova::Site::Format.size(size) }
      end

      def command(id, label, text)
        { 'id' => "cmd-#{id}", 'label' => label, 'text' => text }
      end

      def links
        {
          'slug' => slug, 'public_url' => public_url, 'repo_url' => repo_url, 'repo_file_url' => repo_file_url,
          'key_url' => key_url, 'source_url' => source_url, 'pipeline_api_url' => pipeline_api_url
        }
      end

      def summary
        {
          'title' => config.site.title, 'description' => config.site.description,
          'tumbleweed_snapshot' => state['tumbleweed_snapshot'], 'run' => state['run'], 'release' => state['release'],
          'generated_at' => ::PackmanNova::Site::Format.time(state['generated_at']), 'generated_at_iso' => state['generated_at']
        }
      end
    end
  end
end
