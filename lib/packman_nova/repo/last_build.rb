# frozen_string_literal: true

module PackmanNova
  module Repo
    class LastBuild
      attr_reader :record

      class << self
        def load(workdir)
          record = ::PackmanNova::Utils::JsonFile.read(workdir.last_build_file)
          raise ::PackmanNova::PublishError, "no build record at #{workdir.last_build_file}; run 'packman-nova build' first" unless record

          new(::PackmanNova::State::Schemas.validate!(:build_record, record))
        end
      end

      def initialize(record)
        @record = record
      end

      def run
        record['run']
      end

      def arch(requested, default:)
        recorded = record['arch']
        raise ::PackmanNova::PublishError, "--arch #{requested} does not match the last build (#{recorded})" if requested && recorded && requested != recorded

        requested || recorded || default
      end
    end
  end
end
