# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  module Repo
    class Createrepo
      SCRIPT = <<~SH.freeze
        if [ -n "${SIGN:-}" ]; then
          export GNUPGHOME="$(mktemp -d)"
          gpg --batch --quiet --import #{::PackmanNova::Repo::Signer::KEY_MOUNT}/#{::PackmanNova::Repo::Signer::PRIVATE_KEY}
        fi
        for dir in "$@"; do
          cd "#{::PackmanNova::Repo::Signer::REPO_MOUNT}/$dir"
          createrepo_c --update --retain-old-md=0 --compatibility .
          rm -f repodata/repomd.xml.asc repodata/repomd.xml.key
          if [ -n "${SIGN:-}" ]; then
            gpg --batch --no-tty --detach-sign --armor --yes --always-trust -o repodata/repomd.xml.asc repodata/repomd.xml
            cp #{::PackmanNova::Repo::Signer::KEY_MOUNT}/#{::PackmanNova::Repo::Signer::PUBLIC_KEY} repodata/repomd.xml.key
          fi
        done
      SH

      def initialize(toolbox:)
        @toolbox = toolbox
      end

      def call(repo_dir:, dirs:, key_dir: nil)
        dirs.each { |dir| ::FileUtils.mkdir_p(::File.join(repo_dir, dir)) }
        toolbox.run(SCRIPT, mounts: mounts(repo_dir, key_dir), args: dirs, env: { 'SIGN' => key_dir ? '1' : '' })
        dirs
      end

      private

      attr_reader :toolbox

      def mounts(repo_dir, key_dir)
        return [::PackmanNova::Container::Mount.new(source: repo_dir, target: ::PackmanNova::Repo::Signer::REPO_MOUNT)] unless key_dir

        ::PackmanNova::Repo::Signer.mounts(dir: repo_dir, key_dir:)
      end
    end
  end
end
