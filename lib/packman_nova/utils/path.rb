# frozen_string_literal: true

require 'fileutils'
require 'securerandom'

module PackmanNova
  module Utils
    module Path
      module_function

      def mkpath(path)
        ::FileUtils.mkdir_p(path)
        path
      end

      def atomic_write(path, content, perm: 0o644)
        mkpath(::File.dirname(path))
        tmp = temp_sibling(path)
        write_synced(tmp, content, perm)
        ::File.rename(tmp, path)
        path
      ensure
        ::FileUtils.rm_f(tmp) if tmp
      end

      def atomic_rename_dir(tmp_dir, final_dir)
        trash = temp_sibling(final_dir)
        ::File.rename(final_dir, trash) if ::File.exist?(final_dir)
        ::File.rename(tmp_dir, final_dir)
        final_dir
      ensure
        ::FileUtils.rm_rf(trash) if trash
      end

      def hardlink_or_copy(src, dst)
        mkpath(::File.dirname(dst))
        ::FileUtils.rm_f(dst)
        begin
          ::File.link(src, dst)
        rescue ::Errno::EXDEV, ::Errno::EPERM, ::Errno::EMLINK, ::Errno::ENOTSUP
          ::FileUtils.cp(src, dst)
        end
        dst
      end

      def write_synced(path, content, perm)
        ::File.open(path, 'wb', perm) do |file|
          file.write(content)
          file.flush
          file.fsync
        end
      end

      def temp_sibling(path)
        ::File.join(::File.dirname(path), ".#{::File.basename(path)}.tmp-#{::Process.pid}-#{::SecureRandom.hex(4)}")
      end
    end
  end
end
