# frozen_string_literal: true

module PackmanNova
  class Manifest
    FILE_NAME = 'package.yml'
    OBS_LINK = 'obs-link'
    NATIVE = 'native'

    Origin = ::Data.define(:project, :package, :pin) do
      def to_s
        "#{project}/#{package}"
      end
    end

    class << self
      def base_name(key)
        key.split(':', 2).first
      end

      def load_file(path, require_checksums: true)
        dir = ::File.dirname(::File.expand_path(path))
        data = ::PackmanNova::Utils::Yaml.load_file(path, symbolize_names: true)
        new(data, dir:, require_checksums:)
      rescue ::Psych::Exception => e
        raise ::PackmanNova::ManifestError, "package #{::File.basename(dir)}: invalid YAML: #{e.message}"
      end
    end

    attr_reader :name, :kind, :tier, :tags, :notes, :origin, :link_delete, :link_patches, :sources, :watch, :spec_name, :dir

    def initialize(data, dir:, require_checksums: true)
      @dir = ::File.expand_path(dir)
      attributes = ::PackmanNova::Manifest::Parser.new(data, label: ::File.basename(@dir), require_checksums:).call
      attributes.each { |key, value| instance_variable_set(:"@#{key}", value.frozen? ? value : value.freeze) }
      validate_spec!
      validate_link_patches!
      freeze
    end

    def enabled?
      @enabled
    end

    def obs_link?
      kind == OBS_LINK
    end

    def native?
      kind == NATIVE
    end

    def vendored_files
      excluded = [FILE_NAME, *sources.map(&:file)]
      ::Dir.children(dir).sort.reject { |entry| entry.start_with?('.') || excluded.include?(entry) }
           .map { |entry| ::File.join(dir, entry) }.select { |path| ::File.file?(path) }
    end

    private

    def validate_link_patches!
      missing = link_patches.reject { |file| ::File.file?(::File.join(dir, file)) }
      raise ::PackmanNova::ManifestError, "package #{name}: link.patches: #{missing.join(', ')} not found in #{dir}" unless missing.empty?
    end

    def validate_spec!
      return if obs_link? || spec_available?

      raise ::PackmanNova::ManifestError, "package #{name}: spec: #{spec_name} not found in #{dir}"
    end

    def spec_available?
      ::File.file?(::File.join(dir, spec_name)) || sources.any? { |source| source.file == spec_name }
    end
  end
end
