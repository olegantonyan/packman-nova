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

    def initialize(status:, result_text:, &on_execute)
      @status = ::BuildFakes::Status.new(status)
      @result_text = result_text
      @on_execute = on_execute
      @executed = []
      @captured = []
    end

    def execute(argv, **)
      executed << argv
      @on_execute&.call(argv)
      @status
    end

    def capture(argv, **)
      captured << argv
      raise ::PackmanNova::SubprocessError.new(cli: argv, status: nil) if @result_text.nil?

      @result_text
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
