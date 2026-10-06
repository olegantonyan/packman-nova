# frozen_string_literal: true

require 'fileutils'
require 'open3'

class GitFixture
  CONFIG = %w[-c user.name=test -c user.email=test@example.org -c commit.gpgsign=false -c tag.gpgsign=false].freeze

  attr_reader :dir

  def initialize(dir)
    @dir = dir
    ::FileUtils.mkdir_p(dir)
    git('init', '--quiet', '--initial-branch=main')
  end

  def url
    "file://#{dir}"
  end

  def commit(files = {}, date: '2026-01-01T12:00:00Z', **named_files)
    files.merge(named_files).each do |name, content|
      path = ::File.join(dir, name)
      ::FileUtils.mkdir_p(::File.dirname(path))
      ::File.write(path, content)
    end
    git('add', '-A')
    git('commit', '--quiet', '-m', 'change', env: { 'GIT_AUTHOR_DATE' => date, 'GIT_COMMITTER_DATE' => date })
    head
  end

  def tag(name)
    git('tag', '-a', '-m', name, name)
  end

  def head
    git('rev-parse', 'HEAD').strip
  end

  def git(*args, env: {})
    output, status = ::Open3.capture2e(env, 'git', '-C', dir, *CONFIG, *args)
    raise "git #{args.join(' ')} failed: #{output}" unless status.success?

    output
  end
end
