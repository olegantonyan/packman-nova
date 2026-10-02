# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::State::Schemas do
  it 'accepts hashes with the required keys' do
    record = { 'schema' => 1, 'run' => 4, 'release' => '1699.4.nova.1', 'started_at' => 'now', 'packages' => {} }

    assert_equal record, ::PackmanNova::State::Schemas.validate!(:build_record, record)
  end

  it 'names missing keys' do
    error = assert_raises(::PackmanNova::Error) { ::PackmanNova::State::Schemas.validate!(:sync_state, { 'schema' => 1 }) }

    assert_match(/missing key\(s\) packages/, error.message)
  end

  it 'rejects unknown schema names' do
    assert_raises(::ArgumentError) { ::PackmanNova::State::Schemas.validate!(:nope, {}) }
  end
end
