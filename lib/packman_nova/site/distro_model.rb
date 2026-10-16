# frozen_string_literal: true

module PackmanNova
  module Site
    class DistroModel
      REPO_FILE_NAME = ::PackmanNova::Repo::Layout::REPO_FILE
      PACKAGES_FILE_NAME = ::PackmanNova::Repo::Layout::PACKAGES_FILE
      SOURCE_DIR = 'src'
      SUCCEEDED = ::PackmanNova::Pbuild::ResultParser::SUCCEEDED

      def initialize(config:, state:)
        @config = config
        @state = state || {}
      end

      def id
        config.distro.id
      end

      def published?
        !state.empty?
      end

      def public_url
        layout.public_url(config.repository.public_url)
      end

      def repo_url
        "#{public_url}/#{layout.path}"
      end

      def repo_file_url
        "#{repo_url}/#{REPO_FILE_NAME}"
      end

      def commands
        [
          command('add', 'Add the repo', "sudo zypper ar -f -p #{::PackmanNova::Repo::RepoFile::PRIORITY} #{repo_file_url}"),
          command('refresh', 'Import the key', 'sudo zypper --gpg-auto-import-keys ref'),
          command('switch', 'Switch packages', "sudo zypper dup --from #{config.repository.slug} --allow-vendor-change")
        ]
      end

      def baseurls
        dirs = config.distro.arches + (config.repository.publish_srpms? ? [SOURCE_DIR] : [])
        dirs.map { |dir| { 'arch' => dir, 'url' => "#{repo_url}/#{dir}" } }
      end

      def packages
        @packages ||= state.fetch('packages', {}).sort_by { |name, _entry| name }.map do |name, entry|
          ::PackmanNova::Site::PackageRow.new(name:, entry:, files:, repo_url:, anchor_prefix: id).to_h
        end
      end

      def totals
        succeeded = packages.count { |row| row['status'] == SUCCEEDED }
        { 'packages' => packages.size, 'succeeded' => succeeded, 'not_succeeded' => packages.size - succeeded }.merge(file_totals)
      end

      def to_h
        links.merge(summary, 'commands' => commands, 'baseurls' => baseurls, 'totals' => totals, 'packages' => packages)
      end

      private

      attr_reader :config, :state

      def layout
        @layout ||= ::PackmanNova::Repo::Layout.from_config(config, root: ::PackmanNova::Repo::Layout.localfs_root(config))
      end

      def files
        state.fetch('files', {})
      end

      def file_totals
        sources = files.keys.count { |path| path.start_with?("#{SOURCE_DIR}/") }
        size = files.values.sum { |meta| meta['size'].to_i }
        { 'binary_rpms' => files.size - sources, 'source_rpms' => sources, 'size' => ::PackmanNova::Site::Format.size(size) }
      end

      def links
        { 'repo_url' => repo_url, 'repo_file_url' => repo_file_url, 'packages_url' => "#{repo_url}/#{PACKAGES_FILE_NAME}" }
      end

      def summary
        {
          'id' => id, 'name' => config.distro.name, 'published' => published?, 'slug' => config.repository.slug,
          'distro_snapshot' => state['distro_snapshot'], 'run' => state['run'], 'release' => state['release'], **generated
        }
      end

      def generated
        { 'generated_at' => ::PackmanNova::Site::Format.time(state['generated_at']), 'generated_at_iso' => state['generated_at'] }
      end

      def command(name, label, text)
        { 'id' => "#{id}-cmd-#{name}", 'label' => label, 'text' => text }
      end
    end
  end
end
