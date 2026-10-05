# frozen_string_literal: true

require 'time'

module PackmanNova
  module State
    class BuildRecord
      def initialize(workdir:)
        @workdir = workdir
      end

      def compose(results:, codes:, details: {}, baselibs: {}, **fields)
        packages = (results.keys | codes.keys).sort.to_h do |key|
          [key, with_baselibs(package_entry(key, results[key], codes[key]).merge('details' => details[key]), baselibs[key])]
        end
        { 'schema' => ::PackmanNova::State::Schemas::VERSION, **stringify(fields), 'codes' => tally(packages), 'packages' => packages }
      end

      def write(record)
        ::PackmanNova::State::Schemas.validate!(:build_record, record)
        path = workdir.build_record_file(record.fetch('run'))
        ::PackmanNova::Utils::JsonFile.write(path, record)
        ::PackmanNova::Utils::JsonFile.write(workdir.last_build_file, record)
        path
      end

      def last
        ::PackmanNova::Utils::JsonFile.read(workdir.last_build_file)
      end

      def read(run)
        ::PackmanNova::Utils::JsonFile.read(workdir.build_record_file(run))
      end

      private

      attr_reader :workdir

      def package_entry(key, result, code)
        return empty_entry(key, code) unless result

        {
          'code' => code || result.status || 'unknown', 'flavor' => result.flavor, 'reason' => result.reason,
          'rpms' => result.binary_rpms, 'debuginfo_rpms' => result.debuginfo_rpms, 'srpm' => result.srpm,
          'log' => result.log && relative(result.log), 'built_at' => result.built_at&.utc&.iso8601, 'duration_sec' => result.duration_sec
        }
      end

      def with_baselibs(entry, baselibs)
        return entry unless baselibs

        merged = entry.merge('baselibs' => baselibs)
        return merged unless failure?(baselibs['code']) && !failure?(entry['code'])

        merged.merge('code' => baselibs['code'], 'details' => "#{baselibs['arch']}: #{baselibs['details'] || baselibs['code']}")
      end

      def failure?(code)
        ::PackmanNova::Pbuild::ResultParser::FAILURE_CODES.include?(code)
      end

      def empty_entry(key, code)
        {
          'code' => code || 'unknown', 'flavor' => key.split(':', 2)[1], 'reason' => nil, 'rpms' => [], 'debuginfo_rpms' => [],
          'srpm' => nil, 'log' => nil, 'built_at' => nil, 'duration_sec' => nil
        }
      end

      def stringify(fields)
        fields.to_h { |key, value| [key.to_s, value.is_a?(::Time) ? value.utc.iso8601 : value] }
      end

      def tally(packages)
        packages.values.map { |entry| entry['code'] }.tally.sort.to_h
      end

      def relative(path)
        path.delete_prefix("#{workdir.root}/")
      end
    end
  end
end
