# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  module Repo
    class BuildLogs
      def initialize(config:)
        @failure_log = ::PackmanNova::Pbuild::FailureLog.new(config:)
      end

      def call(layout:, record:)
        names = publish(layout, record)
        (::Dir.glob('*.log', base: layout.logs_dir) - names.values).each { |name| ::FileUtils.rm_f(::File.join(layout.logs_dir, name)) }
        names.transform_values { |name| "#{::PackmanNova::Repo::Layout::LOGS}/#{name}" }
      end

      private

      attr_reader :failure_log

      def publish(layout, record)
        ::PackmanNova::State::BuildRecord.failed_packages(record).each_with_object({}) do |key, names|
          source = failure_log.path(key, record.dig('packages', key))
          next unless source && ::File.file?(source)

          names[key] = "#{key}.log"
          ::PackmanNova::Utils::Path.atomic_write(::File.join(layout.logs_dir, names[key]), ::File.binread(source).force_encoding(::Encoding::UTF_8).scrub)
        end
      end
    end
  end
end
