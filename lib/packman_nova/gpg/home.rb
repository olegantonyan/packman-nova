# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

module PackmanNova
  class Gpg
    class Home
      class << self
        def open(executor)
          dir = ::Dir.mktmpdir('packman-nova-gpg-')
          ::File.chmod(0o700, dir)
          yield new(dir:, executor:)
        ensure
          if dir
            executor.shutdown(dir)
            ::FileUtils.rm_rf(dir)
          end
        end
      end

      attr_reader :dir

      def initialize(dir:, executor:)
        @dir = dir
        @executor = executor
      end

      def write(name, content)
        ::File.write(::File.join(dir, name), content, perm: 0o600)
        path(name)
      end

      def path(name)
        executor.path(dir, name)
      end

      def gpg(*args)
        executor.capture(args, home: dir)
      end

      private

      attr_reader :executor
    end
  end
end
