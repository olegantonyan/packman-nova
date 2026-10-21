# frozen_string_literal: true

class SrcRpmFixture
  LEAD = ('L' * 96).b
  HEADER_START = LEAD.bytesize

  class << self
    def header(strings)
      store = +''.b
      entries = strings.map do |tag, value|
        offset = store.bytesize
        store << value.b << "\0"
        [tag, 6, offset, 1].pack('N4')
      end
      ["\x8E\xAD\xE8\x01".b, "\0" * 4, [entries.size, store.bytesize].pack('N2'), *entries, store].join.b
    end

    def src_rpm(disturl)
      header = header(1000 => 'demo', 1123 => disturl)
      [LEAD + header + 'payload'.b, HEADER_START...(HEADER_START + header.bytesize)]
    end

    def primary(packages)
      blocks = packages.map do |name, (location, range)|
        <<~XML
          <package type="rpm">
            <name>#{name}</name>
            <location href="#{location}"/>
            <format><rpm:header-range start="#{range.begin}" end="#{range.end}"/></format>
          </package>
        XML
      end
      %(<metadata packages="#{packages.size}">\n#{blocks.join}</metadata>\n)
    end

    def repomd(href)
      %(<repomd>\n  <data type="primary">\n    <location href="#{href}"/>\n  </data>\n</repomd>\n)
    end

    def gzip(content)
      io = ::StringIO.new(+''.b)
      gz = ::Zlib::GzipWriter.new(io)
      gz.write(content)
      gz.close
      io.string
    end
  end
end
