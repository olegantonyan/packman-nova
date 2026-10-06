# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Cli::Update do
  def run_update(**options)
    config = load_config(overrides: { offline: true, workdir: '/nonexistent' })
    ::PackmanNova::Cli::Update.new(config:, logger: null_logger, options:, out: ::StringIO.new).call
  end

  it 'rejects --check together with --version' do
    error = assert_raises(::PackmanNova::UpstreamError) { run_update(check: true, version: '1.0') }

    assert_match(/exclusive/, error.message)
  end

  it 'refuses offline' do
    assert_raises(::PackmanNova::UpstreamError) { run_update(check: true) }
  end
end
