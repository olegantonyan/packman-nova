# frozen_string_literal: true

require 'fileutils'
require 'time'

module PackmanNova
  module State
    class RunCounter
      FILE_NAME = 'run-counter.json'

      attr_reader :path

      def initialize(workdir:, clock: -> { ::Time.now.utc })
        @path = workdir.state_file(FILE_NAME)
        @clock = clock
      end

      def current
        run = read['run']
        run.is_a?(::Integer) && run.positive? ? run : 0
      end

      def last_release
        read['last_release']
      end

      def peek(floor: 0)
        [current, floor.to_i].max + 1
      end

      def next!(floor: 0)
        run = peek(floor: floor)
        release = block_given? ? yield(run) : nil
        ::PackmanNova::Utils::JsonFile.write(path, { 'run' => run, 'updated_at' => clock.call.iso8601, 'last_release' => release })
        run
      end

      def snapshot
        ::File.file?(path) ? ::File.read(path) : nil
      end

      def restore!(snapshot)
        snapshot ? ::PackmanNova::Utils::Path.atomic_write(path, snapshot) : ::FileUtils.rm_f(path)
      end

      private

      attr_reader :clock

      def read
        data = ::PackmanNova::Utils::JsonFile.read(path, default: {})
        data.is_a?(::Hash) ? data : {}
      rescue ::PackmanNova::Error
        {}
      end
    end
  end
end
