# frozen_string_literal: true

require 'shellwords'

module PackmanNova
  class Error < ::StandardError; end

  class ConfigError < ::PackmanNova::Error; end

  class ManifestError < ::PackmanNova::Error; end

  class SyncError < ::PackmanNova::Error; end

  class PublishError < ::PackmanNova::Error; end

  class GpgError < ::PackmanNova::Error; end

  class LockError < ::PackmanNova::Error; end

  class DownloadError < ::PackmanNova::Error; end

  class BuildError < ::PackmanNova::Error; end

  class UpstreamError < ::PackmanNova::Error; end

  class SubprocessError < ::PackmanNova::Error
    OUTPUT_TAIL_LINES = 20

    attr_reader :cli, :status, :output

    def initialize(message = nil, cli:, status:, output: '')
      @cli = cli
      @status = status
      @output = output.to_s
      super(message || default_message)
    end

    private

    def default_message
      tail = output.lines.last(OUTPUT_TAIL_LINES).join.strip
      summary = "command failed (#{status_text}): #{::Shellwords.join(cli.map(&:to_s))}"
      tail.empty? ? summary : "#{summary}\n#{tail}"
    end

    def status_text
      return 'not started' if status.nil?
      return "signal #{status.termsig}" if status.signaled?

      "exit #{status.exitstatus}"
    end
  end
end
