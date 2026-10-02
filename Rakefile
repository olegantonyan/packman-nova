# frozen_string_literal: true

require 'rake/testtask'

::Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = ::FileList['test/**/test_*.rb'].exclude('test/integration/**/*')
end

::Rake::TestTask.new(:integration_test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = ::FileList['test/integration/**/test_*.rb']
end

require 'rubocop/rake_task'

::RuboCop::RakeTask.new

task default: %i[test rubocop]
