# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'

module PackmanNova
  class Workdir
    TOP_LEVEL_DIRS = %w[project build-root cache state logs tmp repo].freeze
    LOG_TIMESTAMP_FORMAT = '%Y%m%d-%H%M%S'

    attr_reader :root

    def initialize(root:)
      @root = root.to_s.freeze
      freeze
    end

    def project_dir = join('project')
    def configs_dir = ::File.join(project_dir, '_configs')
    def config_file = ::File.join(project_dir, '_config')
    def package_dir(name) = ::File.join(project_dir, name)
    def results_dir(reponame:, arch:) = ::File.join(project_dir, "_build.#{reponame}.#{arch}")
    def pbuild_state_dir = ::File.join(project_dir, '.pbuild')
    def build_root = join('build-root')
    def cache_dir = join('cache')
    def obs_cache_dir(project:, package:) = ::File.join(cache_dir, 'obs', project, package)
    def prjconf_cache_dir = ::File.join(cache_dir, 'prjconf')
    def public_key_file = ::File.join(cache_dir, 'public-key.asc')
    def state_dir = join('state')
    def state_file(name) = ::File.join(state_dir, name)
    def builds_dir = ::File.join(state_dir, 'builds')
    def build_record_file(run) = ::File.join(builds_dir, "#{run}.json")
    def last_build_file = state_file('last-build.json')
    def repo_dir = join('repo')
    def repo_mirror_dir = join('repo-mirror')
    def logs_dir = join('logs')
    def tmp_dir = join('tmp')
    def lock_file = join('.lock')

    def cache_blob(sha256: nil, md5: nil)
      raise ::ArgumentError, 'cache_blob needs exactly one of sha256: or md5:' unless [sha256, md5].compact.size == 1

      sha256 ? ::File.join(cache_dir, 'blobs', 'sha256', sha256) : ::File.join(cache_dir, 'blobs', 'md5', md5)
    end

    def log_file(command, now: ::Time.now)
      ::File.join(logs_dir, "#{now.strftime(LOG_TIMESTAMP_FORMAT)}-#{command}.log")
    end

    def mktmpdir(prefix)
      ::FileUtils.mkdir_p(tmp_dir)
      path = ::Dir.mktmpdir(prefix, tmp_dir)
      ::File.chmod(0o700, path)
      return path unless block_given?

      begin
        yield path
      ensure
        ::FileUtils.rm_rf(path)
      end
    end

    def with_lock(blocking: false)
      ::FileUtils.mkdir_p(root)
      ::File.open(lock_file, ::File::RDWR | ::File::CREAT, 0o644) do |file|
        acquire_lock(file, blocking)
        yield
      ensure
        file.flock(::File::LOCK_UN)
      end
    end

    def prepare!
      TOP_LEVEL_DIRS.each { |dir| ::FileUtils.mkdir_p(join(dir)) }
      self
    end

    def exist?
      ::File.directory?(root)
    end

    def free_bytes
      output, status = ::Open3.capture2('df', '-B1', '--output=avail', existing_ancestor)
      raise ::PackmanNova::Error, "df failed for #{existing_ancestor}" unless status.success?

      ::Kernel.Integer(output.lines.last.strip)
    end

    def existing_ancestor
      path = ::File.expand_path(root)
      path = ::File.dirname(path) until ::File.exist?(path)
      path
    end

    private

    def join(name)
      ::File.join(root, name)
    end

    def acquire_lock(file, blocking)
      mode = blocking ? ::File::LOCK_EX : ::File::LOCK_EX | ::File::LOCK_NB
      raise ::PackmanNova::LockError, "another packman-nova process holds #{lock_file}" unless file.flock(mode)

      file.truncate(0)
      file.write("#{::Process.pid}\n")
      file.flush
    end
  end
end
