# frozen_string_literal: true

module PackmanNova
  module Pbuild
    module JobHistory
      module_function

      def read(path)
        ::File.file?(path) ? parse(::File.read(path)) : {}
      rescue ::PackmanNova::Error
        {}
      end

      def parse(xml)
        ::PackmanNova::Utils::Xml.attributes(::PackmanNova::Utils::Xml.parse(xml), '/jobhistlist/jobhist').each_with_object({}) do |job, acc|
          acc[job['package']] = entry(job) if job['package']
        end
      end

      def entry(job)
        start = time(job['starttime'])
        finish = time(job['endtime'])
        { code: job['code'], starttime: start, endtime: finish, duration_sec: start && finish ? (finish - start).to_i : nil, reason: job['reason'] }
      end

      def time(value)
        value.to_s.match?(/\A\d+\z/) ? ::Time.at(::Kernel.Integer(value, 10)).utc : nil
      end
    end
  end
end
