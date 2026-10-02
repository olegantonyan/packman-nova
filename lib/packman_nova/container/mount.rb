# frozen_string_literal: true

module PackmanNova
  module Container
    class Mount
      attr_reader :source, :target, :readonly

      def initialize(source:, target:, readonly: false)
        [source, target].each do |path|
          raise ::ArgumentError, "mount path must not contain a comma: #{path}" if path.to_s.include?(',')
        end
        @source = source.to_s
        @target = target.to_s
        @readonly = readonly
        freeze
      end

      def readonly?
        readonly
      end

      def to_args
        spec = "type=bind,source=#{source},target=#{target}"
        ['--mount', readonly? ? "#{spec},readonly" : spec]
      end
    end
  end
end
