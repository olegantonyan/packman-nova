# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Logging::Logger do
  it 'formats lines as HH:MM:SS [L] message' do
    logger, io = string_logger
    logger.info('hello')
    logger.warn('careful')

    assert_match(/\A\d\d:\d\d:\d\d \[I\] hello\n\d\d:\d\d:\d\d \[W\] careful\n\z/, io.string)
  end

  it 'prints container output raw' do
    logger, io = string_logger
    logger.add(::Logger::INFO, "[  12s] compiling\n", 'container')

    assert_equal "[  12s] compiling\n", io.string
  end

  it 'masks secrets in messages and container output' do
    logger, io = string_logger(filters: ['s3cr3t'])
    logger.info('token=s3cr3t')
    logger.add(::Logger::INFO, 'raw s3cr3t', 'container')

    assert_equal 2, io.string.scan('***').size
    refute_includes io.string, 's3cr3t'
  end

  it 'returns a new logger with extra filters' do
    logger, io = string_logger
    logger.add_filters('hidden', '').info('hidden value')

    assert_includes io.string, '*** value'
  end

  it 'returns a new logger with extra outputs' do
    logger, io = string_logger
    extra = ::StringIO.new
    logger.add_outputs(extra).info('both')

    assert_includes io.string, 'both'
    assert_includes extra.string, 'both'
  end

  it 'logs commands shell-escaped' do
    logger, io = string_logger
    logger.command(['podman', 'run', 'a b'])

    assert_includes io.string, "[I] $ podman run a\\ b\n"
  end

  it 'respects the level' do
    logger, io = string_logger(level: ::Logger::WARN)
    logger.info('quiet')

    assert_empty io.string
  end

  it 'does not colour non-tty outputs' do
    logger, io = string_logger
    logger.error('plain')

    refute_includes io.string, "\e["
  end
end

describe ::PackmanNova::Logging::Multioutput do
  let(:tty) do
    ::StringIO.new.tap { |io| io.define_singleton_method(:tty?) { true } }
  end

  it 'colours level markers on a tty' do
    ::PackmanNova::Logging::Multioutput.new(tty, env: {}).write("08:00:00 [E] boom\n")

    assert_equal "\e[31m08:00:00 [E] boom\e[0m\n", tty.string
  end

  it 'honours NO_COLOR' do
    ::PackmanNova::Logging::Multioutput.new(tty, env: { 'NO_COLOR' => '1' }).write("08:00:00 [I] hi\n")

    assert_equal "08:00:00 [I] hi\n", tty.string
  end
end
