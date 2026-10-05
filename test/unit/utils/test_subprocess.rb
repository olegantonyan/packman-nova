# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Utils::Subprocess do
  let(:log) { string_logger }
  let(:subprocess) { ::PackmanNova::Utils::Subprocess.new(logger: log.first) }

  it 'streams output lines to the block and the logger' do
    lines = []
    status = subprocess.execute(['sh', '-c', 'echo one; echo two >&2']) { |line| lines << line }

    assert_predicate status, :success?
    assert_equal %W[one\n two\n], lines.sort
    assert_match(/\[I\] \$ sh -c .*\n(one|two)\n(one|two)\n\z/, log.last.string)
  end

  it 'passes env' do
    lines = []
    subprocess.execute(['sh', '-c', 'echo "$FOO"'], env: { 'FOO' => 'bar' }) { |line| lines << line }

    assert_equal ["bar\n"], lines
  end

  it 'terminates the process on timeout' do
    started = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    status = subprocess.execute(%w[sleep 30], timeout_sec: 0.2)

    assert_predicate status, :signaled?
    assert_operator ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - started, :<, 5
  end

  it 'captures stdout' do
    assert_equal "hello\n", subprocess.capture(%w[echo hello])
  end

  it 'raises SubprocessError with stderr on failure' do
    error = assert_raises(::PackmanNova::SubprocessError) { subprocess.capture(['sh', '-c', 'echo bad >&2; exit 3']) }

    assert_equal 3, error.status.exitstatus
    assert_includes error.message, 'bad'
  end

  it 'raises SubprocessError when the executable is missing' do
    assert_raises(::PackmanNova::SubprocessError) { subprocess.capture(['packman-nova-no-such-binary']) }
  end

  it 'reports success and combined output with capture?' do
    assert_equal [true, "out\nerr\n"], subprocess.capture?(['sh', '-c', 'echo out; echo err >&2'])
    refute subprocess.capture?(['false']).first
  end
end
