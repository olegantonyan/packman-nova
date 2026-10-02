# frozen_string_literal: true

module PackmanNova
  class Gpg
    Key = ::Data.define(:private_armor, :public_armor, :key_id, :fingerprint) do
      def private_base64
        ::PackmanNova::Gpg.to_base64(private_armor)
      end

      def short_id
        key_id[-8..].downcase
      end

      def inspect
        "#<#{self.class.name} key_id=#{key_id} fingerprint=#{fingerprint}>"
      end

      alias_method :to_s, :inspect
    end
  end
end
