# frozen_string_literal: true

module PackmanNova
  class Cli
    class Image < ::PackmanNova::Cli::Command
      SUBCOMMANDS = %w[build info].freeze

      class << self
        def summary
          'build or inspect the builder container image'
        end

        def usage
          '<build|info> [options]'
        end

        def options(parser, options)
          parser.on('--[no-]cache', 'use the layer cache (build, default: yes)') { |value| options[:cache] = value }
          parser.on('--tag TAG', 'image tag (default: container.image)') { |value| options[:tag] = value }
        end
      end

      def call
        subcommand = args.first || 'info'
        raise ::OptionParser::InvalidArgument, "image: unknown subcommand '#{subcommand}', expected #{SUBCOMMANDS.join(' or ')}" unless SUBCOMMANDS.include?(subcommand)

        subcommand == 'build' ? build : info
      end

      private

      def image
        @image ||= ::PackmanNova::Pbuild::Environment.new(config:, logger:).image(tag: options[:tag])
      end

      def build
        record = image.build!(no_cache: options[:cache] == false)
        out.puts("built #{record.fetch('tag')} #{record.fetch('id')}")
        0
      end

      def info
        return print_fields('tag' => image.tag, 'present' => 'no', 'containerfile' => image.containerfile) unless image.exists?

        print_fields('tag' => image.tag, 'present' => 'yes', 'id' => image.id, 'containerfile' => image.containerfile, **freshness)
      end

      def freshness
        { 'up_to_date' => image.up_to_date? ? 'yes' : 'no (run image build)', 'built_at' => image.record['built_at'] }
      end

      def print_fields(fields)
        fields.each { |key, value| out.puts(format('%-14<key>s %<value>s', key: "#{key}:", value: value || '-')) }
        0
      end
    end
  end
end
