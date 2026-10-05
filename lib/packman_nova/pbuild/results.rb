# frozen_string_literal: true

module PackmanNova
  module Pbuild
    class Results
      JOB_HISTORY = '_jobhistory'
      SHORT_MD5 = 8

      class << self
        def scan(results_dir)
          new(results_dir:).scan
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
        return ::PackmanNova::Pbuild::ResultParser::SUCCEEDED if ::File.file?("#{meta}.success") && ::FileUtils.identical?(meta, "#{meta}.success")

        'unknown'
      end

      private

      def package_dirs
        ::Dir.children(results_dir).reject { |name| name.start_with?('.', '_') }.select { |name| ::File.directory?(::File.join(results_dir, name)) }.sort
      end

      def package_result(key)
        dir = ::File.join(results_dir, key)
        ::PackmanNova::Pbuild::PackageResult.new(
          key:, dir:, rpm_files: ::Dir.children(dir).select { |file| file.end_with?('.rpm') }, status: status_of(dir),
          reason: read_reason(::File.join(dir, '_reason')), log: existing(::File.join(dir, '_log')), **timing(key, dir)
        )
      end

      def timing(key, dir)
        job = job_history.fetch(key, {})
        { built_at: job[:endtime] || mtime(::File.join(dir, '_meta')), duration_sec: job[:duration_sec] }
      end

      def job_history
        @job_history ||= read_xml(::File.join(results_dir, JOB_HISTORY), {}) do |doc|
          ::PackmanNova::Utils::Xml.attributes(doc, '/jobhistlist/jobhist').select { |job| job['package'] }.to_h { |job| [job['package'], job_entry(job)] }
        end
      end

      def job_entry(job)
        start = time(job['starttime'])
        finish = time(job['endtime'])
        { endtime: finish, duration_sec: start && finish ? (finish - start).to_i : nil }
      end

      def time(value)
        value.to_s.match?(/\A\d+\z/) ? ::Time.at(::Kernel.Integer(value, 10)).utc : nil
      end

      def read_reason(path)
        read_xml(path, nil) do |doc|
          explain = ::PackmanNova::Utils::Xml.text(doc, '/reason/explain').to_s.strip
          [explain, reason_details(doc)].compact.join(': ') unless explain.empty?
        end
      end

      def reason_details(doc)
        oldsource = ::PackmanNova::Utils::Xml.text(doc, '/reason/oldsource')
        return "old source #{oldsource[0, SHORT_MD5]}" if oldsource

        changes = ::PackmanNova::Utils::Xml.attributes(doc, '/reason/packagechange').map { |change| "#{change['key']} (#{change['change']})" }
        changes.empty? ? nil : changes.join(', ')
      end

      def read_xml(path, fallback)
        ::File.file?(path) ? yield(::PackmanNova::Utils::Xml.parse(::File.read(path))) : fallback
      rescue ::PackmanNova::Error
        fallback
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
