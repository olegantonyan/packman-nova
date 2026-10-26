# frozen_string_literal: true

module BuildFakes
  class Status
    attr_reader :exitstatus

    def initialize(exitstatus)
      @exitstatus = exitstatus
    end

    def success?
      exitstatus.zero?
    end
  end

  class Subprocess
    attr_reader :executed, :captured

    def initialize(status:, result_text:, output: ->(_argv) { [] }, &on_execute)
      @status = status
      @result_text = result_text
      @output = output
      @on_execute = on_execute
      @executed = []
      @captured = []
    end

    def execute(argv, **, &line_block)
      executed << argv
      @on_execute&.call(argv)
      @output.call(argv).each { |line| line_block&.call(line) }
      ::BuildFakes::Status.new(@status.respond_to?(:call) ? @status.call(argv) : @status)
    end

    def capture(argv, **)
      captured << argv
      text = @result_text.respond_to?(:call) ? @result_text.call(argv) : @result_text
      raise ::PackmanNova::SubprocessError.new(cli: argv, status: nil) if text.nil?

      text
    end
  end

  class Image
    attr_reader :tag

    def initialize(tag)
      @tag = tag
    end

    def ensure!
      'sha256:feed'
    end
  end
end
