# frozen_string_literal: true

module PackmanNova
  class Sync
    class LinkFiles
      PATCH_LINE = /\APatch(\d*):/
      PREAMBLE_LINE = /\A(?:Patch|Source)\d*:/
      APPLIES_PATCHES = /^%(?:autosetup|autopatch)\b/

      def initialize(manifest:, cache:)
        @manifest = manifest
        @cache = cache
      end

      def patches?
        !manifest.link_patches.empty?
      end

      def files
        names.map do |name|
          path = ::File.join(manifest.dir, name)
          ::PackmanNova::Sync::ExpectedFile.new(name:, source: path, md5: ::PackmanNova::Utils::Digest.md5_file(path))
        end
      end

      def spec(original)
        content = patched(::File.read(original.source))
        md5 = ::PackmanNova::Utils::Digest.md5_string(content)
        path = cache.store_md5(md5:, size: content.bytesize) { |tmp| ::File.write(tmp, content) }
        ::PackmanNova::Sync::ExpectedFile.new(name: original.name, source: path, md5:, blob: true)
      end

      private

      attr_reader :manifest, :cache

      def names
        manifest.link_patches + manifest.link_add
      end

      def patched(content)
        fail!('does not apply patches with %autosetup or %autopatch') unless content.match?(APPLIES_PATCHES)

        lines = content.lines
        prep = lines.index { |line| line.start_with?('%prep') } || fail!('has no %prep')
        anchor = lines[0...prep].rindex { |line| line.match?(PREAMBLE_LINE) } || fail!('has no Source or Patch line before %prep')
        lines.insert(anchor + 1, *patch_lines(lines)).join
      end

      def patch_lines(lines)
        first = lines.filter_map { |line| line[PATCH_LINE, 1] }.map(&:to_i).max.to_i + 1
        manifest.link_patches.each_with_index.map { |name, index| "Patch#{first + index}:#{' ' * 8}#{name}\n" }
      end

      def fail!(message)
        raise ::PackmanNova::SyncError, "#{manifest.name}: link.patches: #{manifest.spec_name} #{message}"
      end
    end
  end
end
