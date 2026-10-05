# frozen_string_literal: true

module PackmanNova
  module Repo
    class RpmQuery
      MOUNT = '/rpms'
      SIGNATURE = '%|DSAHEADER?{%{DSAHEADER:pgpsig}}:{%|RSAHEADER?{%{RSAHEADER:pgpsig}}:{%|SIGGPG?{%{SIGGPG:pgpsig}}:{%|SIGPGP?{%{SIGPGP:pgpsig}}:{(none)}|}|}|}|'
      FORMAT = "%{NAME}\\t%{EVR}\\t%{ARCH}\\t%{SOURCERPM}\\t#{SIGNATURE}\\t%{SUMMARY}\\n".freeze
      SCRIPT = <<~SH.freeze
        cd #{MOUNT}
        for file in "$@"; do
          printf '%s\\t' "$file"
          rpm -qp --nosignature --nodigest --qf "$QUERY_FORMAT" "$file"
        done
      SH
      NONE = '(none)'

      Info = ::Data.define(:name, :evr, :arch, :sourcerpm, :pgpsig, :summary) do
        def version
          evr_parts.first
        end

        def release
          evr_parts.last
        end

        def signed?
          !pgpsig.empty? && pgpsig != ::PackmanNova::Repo::RpmQuery::NONE
        end

        def key_id
          pgpsig[/key id (\h+)/i, 1]&.downcase
        end

        private

        def evr_parts
          evr.sub(/\A\d+:/, '').split('-', 2)
        end
      end

      class << self
        def parse(output)
          output.each_line.with_object({}) do |line, acc|
            file, *fields = line.chomp.split("\t", 7)
            next if fields.size < 6

            acc[file] = Info.new(*fields.first(6))
          end
        end
      end

      def initialize(toolbox:)
        @toolbox = toolbox
      end

      def call(dir:, files:)
        return {} if files.empty?

        mounts = [::PackmanNova::Container::Mount.new(source: dir, target: MOUNT, readonly: true)]
        result = self.class.parse(toolbox.capture(SCRIPT, mounts:, args: files, env: { 'QUERY_FORMAT' => FORMAT }))
        missing = files - result.keys
        raise ::PackmanNova::PublishError, "rpm query returned nothing for #{missing.join(', ')}" unless missing.empty?

        result
      end

      private

      attr_reader :toolbox
    end
  end
end
