# frozen_string_literal: true

module PackmanNova
  class Gpg
    Info = ::Data.define(:key_id, :fingerprint, :uids, :secret) do
      class << self
        def parse(colons)
          primary, *own = key_records(colons.lines.map { |line| line.chomp.split(':', -1) })
          new(key_id: primary[4], fingerprint: fingerprint(own), uids: uids(own), secret: primary[0] == 'sec')
        end

        def key_records(records)
          start = records.index { |record| primary?(record) }
          raise ::PackmanNova::GpgError, 'no PGP key found' unless start

          [records[start], *records[(start + 1)..].take_while { |record| !primary?(record) }]
        end

        def primary?(record)
          %w[pub sec].include?(record[0])
        end

        def fingerprint(records)
          value = records.find { |record| record[0] == 'fpr' }&.fetch(9)
          raise ::PackmanNova::GpgError, 'gpg did not report a fingerprint' if value.to_s.empty?

          value
        end

        def uids(records)
          records.select { |record| record[0] == 'uid' }.map { |record| record[9].to_s.gsub(/\\x(\h\h)/) { ::Regexp.last_match(1).hex.chr } }
        end
      end

      def secret?
        secret
      end

      def short_id
        key_id[-8..].downcase
      end
    end
  end
end
