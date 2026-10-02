# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  class Sync
    class PackageDir
      attr_reader :path

      def initialize(path:)
        @path = path
      end

      def name
        ::File.basename(path)
      end

      def matches?(files)
        return false unless ::File.directory?(path)
        return false unless ::Dir.children(path).sort == files.map(&:name).sort

        files.all? { |file| file.satisfied_by?(::File.join(path, file.name)) }
      end

      def materialize(files)
        ::FileUtils.rm_rf(tmp_path)
        ::FileUtils.mkdir_p(tmp_path)
        files.each { |file| place(file, ::File.join(tmp_path, file.name)) }
        ::PackmanNova::Utils::Path.atomic_rename_dir(tmp_path, path)
      ensure
        ::FileUtils.rm_rf(tmp_path)
      end

      def md5s
        ::Dir.children(path).sort.to_h { |entry| [entry, ::PackmanNova::Utils::Digest.md5_file(::File.join(path, entry))] }
      end

      def remove
        ::FileUtils.rm_rf(path)
      end

      def exist?
        ::File.directory?(path)
      end

      private

      def tmp_path
        ::File.join(::File.dirname(path), ".#{name}.tmp")
      end

      def place(file, destination)
        raise ::PackmanNova::SyncError, "no local copy of #{file.name}" unless file.available?

        if file.blob
          ::PackmanNova::Utils::Path.hardlink_or_copy(file.source, destination)
        else
          ::FileUtils.cp(file.source, destination)
        end
      end
    end
  end
end
