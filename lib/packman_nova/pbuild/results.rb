# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class Results
      JOB_HISTORY = '_jobhistory'

      class << self
        def scan(results_dir)
          new(results_dir: results_dir).scan
        end
      end

      attr_reader :results_dir

      def initialize(results_dir:)
        @results_dir = results_dir
      end

      def scan
        return {} unless ::File.directory?(results_dir)

        package_dirs.to_h { |key| [key, package_result(key)] }
      end

      def status_of(dir)
        meta = ::File.join(dir, '_meta')
        return nil unless ::File.file?(meta)
        return 'failed' if ::File.file?("#{meta}.fail")
        return 'succeeded' if ::File.file?("#{meta}.success") && ::FileUtils.identical?(meta, "#{meta}.success")

        'unknown'
      end

      private

      def package_dirs
        ::Dir.children(results_dir).reject { |name| name.start_with?('.', '_') }.select { |name| ::File.directory?(::File.join(results_dir, name)) }.sort
      end

      def package_result(key)
        dir = ::File.join(results_dir, key)
        ::PackmanNova::Pbuild::PackageResult.new(
          key: key, dir: dir, rpm_files: ::Dir.children(dir).select { |file| file.end_with?('.rpm') }, status: status_of(dir),
          reason: ::PackmanNova::Pbuild::Reason.read(::File.join(dir, '_reason')), log: existing(::File.join(dir, '_log')), **timing(key, dir)
        )
      end

      def timing(key, dir)
        job = job_history.fetch(key, {})
        { built_at: job[:endtime] || mtime(::File.join(dir, '_meta')), duration_sec: job[:duration_sec] }
      end

      def job_history
        @job_history ||= ::PackmanNova::Pbuild::JobHistory.read(::File.join(results_dir, JOB_HISTORY))
      end

      def existing(path)
        ::File.file?(path) ? path : nil
      end

      def mtime(path)
        ::File.file?(path) ? ::File.mtime(path).utc : nil
      end
    end
  end
end
