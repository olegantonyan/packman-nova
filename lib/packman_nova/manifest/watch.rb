# frozen_string_literal: true

module PackmanNova
  class Manifest
    class Watch
      ATTRIBUTES = %i[url pattern git branch tags format file exclude sover commit].freeze
      VERSION_PLACEHOLDER = '%{version}'
      ARCHIVE_EXTENSION = /\.tar(?:\.xz)?\z/

      Sover = ::Data.define(:path, :pattern)

      attr_reader(*ATTRIBUTES)

      def initialize(**attributes)
        unknown = attributes.keys - ATTRIBUTES
        raise ::ArgumentError, "unknown watch attribute(s) #{unknown.join(', ')}" unless unknown.empty?

        ATTRIBUTES.each { |name| instance_variable_set(:"@#{name}", attributes[name]) }
        @exclude = (exclude || []).dup.freeze
        freeze
      end

      def http?
        !url.nil?
      end

      def git?
        !git.nil?
      end

      def branch?
        !branch.nil?
      end

      def snapshot?
        !file.nil?
      end

      def version_regexp
        ::Regexp.new(http? ? pattern : tags)
      end

      def file_for(version)
        file.gsub(VERSION_PLACEHOLDER, version)
      end

      def file_regexp
        parts = file.split(VERSION_PLACEHOLDER, -1).map { |part| ::Regexp.escape(part) }
        ::Regexp.new("\\A#{parts.join('.+')}\\z")
      end

      def archive_dir(version)
        file_for(version).sub(ARCHIVE_EXTENSION, '')
      end
    end
  end
end
