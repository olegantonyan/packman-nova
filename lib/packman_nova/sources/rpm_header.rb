# frozen_string_literal: true

module PackmanNova
  module Sources
    class RpmHeader
      MAGIC = "\x8E\xAD\xE8".b
      INTRO_SIZE = 16
      ENTRY_SIZE = 16
      DISTURL = 1123

      def initialize(bytes)
        @bytes = bytes.b
        raise ::PackmanNova::SyncError, 'not an rpm header' unless @bytes.start_with?(MAGIC) && @bytes.bytesize >= INTRO_SIZE
      end

      def disturl
        string(DISTURL)
      end

      private

      attr_reader :bytes

      def string(tag)
        offset = entries.find { |entry_tag, _type, _offset| entry_tag == tag }&.at(2)
        offset && bytes.byteslice(store + offset, bytes.bytesize).unpack1('Z*')
      end

      def entries
        (0...count).map { |index| bytes.byteslice(INTRO_SIZE + (index * ENTRY_SIZE), ENTRY_SIZE).unpack('N3') }
      end

      def count
        bytes.byteslice(8, 4).unpack1('N')
      end

      def store
        INTRO_SIZE + (count * ENTRY_SIZE)
      end
    end
  end
end
