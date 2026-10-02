# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class PackageResult
      SOURCE_RPM = /\.(?:no)?src\.rpm\z/
      DEBUG_RPM = /-debug(?:info|source)-[^-]+-[^-]+\.rpm\z/
      NOARCH_RPM = /\.noarch\.rpm\z/

      attr_reader :key, :name, :flavor, :dir, :rpm_files, :status, :reason, :log, :built_at, :duration_sec

      def initialize(key:, dir:, rpm_files:, status:, reason: nil, log: nil, built_at: nil, duration_sec: nil)
        @key = key
        @name, @flavor = key.split(':', 2)
        @dir = dir
        @rpm_files = rpm_files.sort.freeze
        @status = status
        @reason = reason
        @log = log
        @built_at = built_at
        @duration_sec = duration_sec
        freeze
      end

      def built_since?(time)
        !built_at.nil? && built_at >= time.floor
      end

      def srpm
        rpm_files.find { |file| SOURCE_RPM.match?(file) }
      end

      def debuginfo_rpms
        rpm_files.select { |file| DEBUG_RPM.match?(file) && !SOURCE_RPM.match?(file) }
      end

      def noarch_rpms
        binary_rpms.grep(NOARCH_RPM)
      end

      def binary_rpms
        rpm_files.reject { |file| SOURCE_RPM.match?(file) || DEBUG_RPM.match?(file) }
      end
    end
  end
end
