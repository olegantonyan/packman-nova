# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::State::RunCounter do
  let(:now) { ::Time.utc(2026, 9, 29, 10, 0, 0) }

  def counter(dir)
    ::PackmanNova::State::RunCounter.new(workdir: ::PackmanNova::Workdir.new(root: dir), clock: -> { now })
  end

  it 'starts at 1 without a file' do
    with_tmpdir do |dir|
      assert_equal 0, counter(dir).current
      assert_equal 1, counter(dir).next!
      assert_equal 1, counter(dir).current
    end
  end

  it 'is monotonic and persists the release' do
    with_tmpdir do |dir|
      counter(dir).next!
      run = counter(dir).next! { |next_run| "1699.#{next_run}.nova.1" }
      data = ::JSON.parse(::File.read(::File.join(dir, 'state', 'run-counter.json')))

      assert_equal 2, run
      assert_equal({ 'run' => 2, 'updated_at' => '2026-09-29T10:00:00Z', 'last_release' => '1699.2.nova.1' }, data)
    end
  end

  it 'takes the maximum of the file and the floor' do
    with_tmpdir do |dir|
      counter(dir).next!

      assert_equal 8, counter(dir).next!(floor: 7)
      assert_equal 9, counter(dir).next!(floor: 3)
    end
  end

  it 'peeks without writing' do
    with_tmpdir do |dir|
      assert_equal 5, counter(dir).peek(floor: 4)
      refute_path_exists ::File.join(dir, 'state', 'run-counter.json')
    end
  end

  it 'starts from the floor when the file is corrupted' do
    with_tmpdir do |dir|
      ::FileUtils.mkdir_p(::File.join(dir, 'state'))
      ::File.write(::File.join(dir, 'state', 'run-counter.json'), '{"run": ')

      assert_equal 0, counter(dir).current
      assert_equal 4, counter(dir).next!(floor: 3)
    end
  end

  it 'ignores a non-integer run' do
    with_tmpdir do |dir|
      ::FileUtils.mkdir_p(::File.join(dir, 'state'))
      ::File.write(::File.join(dir, 'state', 'run-counter.json'), '{"run": "7"}')

      assert_equal 1, counter(dir).next!
    end
  end
end
