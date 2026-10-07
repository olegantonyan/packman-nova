# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  module Pbuild
    class StaleBinaries
      UNRESOLVABLE = 'unresolvable'
      MISSING_LIBRARY = /nothing provides (lib[\w+.-]+?)\.so\.([\d.]+)/
      RPM = /\A(.+)-[^-]+-[^-]+\.[^.]+\.rpm\z/

      def initialize(results_dir:, logger:)
        @results_dir = results_dir
        @logger = logger
      end

      def remove!(parser)
        stale = blocking(parser)
        stale.each do |key, names|
          logger.warn("#{key}: its old #{names.join(', ')} hide the distro's and keep it unresolvable; removing its results and retrying")
          ::FileUtils.rm_rf(::File.join(results_dir, key))
        end
        !stale.empty?
      end

      private

      attr_reader :results_dir, :logger

      def blocking(parser)
        parser.codes.filter_map do |key, code|
          next unless code == UNRESOLVABLE

          blocking = library_packages(parser.details[key].to_s) & own_packages(key)
          [key, blocking] unless blocking.empty?
        end.to_h
      end

      def library_packages(details)
        details.scan(MISSING_LIBRARY).map { |name, version| "#{name}#{version.tr('.', '_')}" }.uniq
      end

      def own_packages(key)
        ::Dir.glob('*.rpm', base: ::File.join(results_dir, key)).filter_map { |file| file[RPM, 1]&.delete_suffix('-32bit') }.uniq
      end
    end
  end
end
