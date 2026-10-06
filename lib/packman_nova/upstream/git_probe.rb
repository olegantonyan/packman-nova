# frozen_string_literal: true

module PackmanNova
  class Upstream
    class GitProbe
      ENV = { 'GIT_TERMINAL_PROMPT' => '0' }.freeze
      PEELED_SUFFIX = '^{}'

      def initialize(subprocess:)
        @subprocess = subprocess
      end

      def call(watch, version: nil)
        return ::PackmanNova::Upstream::Probe.new(version: nil, commit: nil, ref: version) if watch.branch? && version

        watch.branch? ? branch_head(watch) : tag(watch, version)
      end

      private

      attr_reader :subprocess

      def branch_head(watch)
        ref = "refs/heads/#{watch.branch}"
        commit = refs(watch.git, ref).fetch(ref) { raise ::PackmanNova::UpstreamError, "#{watch.git}: no branch #{watch.branch}" }
        ::PackmanNova::Upstream::Probe.new(version: nil, commit:, ref: watch.branch)
      end

      def tag(watch, version)
        tags = matching_tags(watch)
        raise ::PackmanNova::UpstreamError, "#{watch.git}: no tag matches #{watch.tags}" if tags.empty?

        chosen = version || ::PackmanNova::Upstream::VersionCompare.max(tags.keys)
        name, commit = tags.fetch(chosen) { raise ::PackmanNova::UpstreamError, "#{watch.git}: no tag for version #{chosen}" }
        ::PackmanNova::Upstream::Probe.new(version: chosen, commit:, ref: name)
      end

      def matching_tags(watch)
        regexp = watch.version_regexp
        refs('--tags', watch.git).each_with_object({}) do |(ref, commit), tags|
          name = ref.delete_prefix('refs/tags/')
          match = regexp.match(name)
          tags[match[1] || match[0]] = [name, commit] if match
        end
      end

      def refs(*args)
        output = subprocess.capture(['git', 'ls-remote', *args], env: ENV)
        output.lines.map(&:split).each_with_object({}) do |(commit, ref), refs|
          name = ref.delete_suffix(PEELED_SUFFIX)
          refs[name] = commit if ref.end_with?(PEELED_SUFFIX) || !refs.key?(name)
        end
      end
    end
  end
end
