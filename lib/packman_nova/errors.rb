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

  class NotImplementedError < ::PackmanNova::Error; end

  class DownloadError < ::PackmanNova::Error
    attr_reader :url, :attempts

    def initialize(message = nil, url:, attempts:)
      @url = url
      @attempts = attempts
      super(message || "download failed after #{attempts} attempt(s): #{url}")
    end
  end

  class BuildError < ::PackmanNova::Error
    attr_reader :failed_packages

    def initialize(message = nil, failed_packages:)
      @failed_packages = failed_packages
      super(message || "build failed: #{failed_packages.join(', ')}")
    end
  end

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
