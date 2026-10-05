# frozen_string_literal: true

require 'securerandom'

module PackmanNova
  class Cli
    class Check < ::PackmanNova::Cli::Command
      MIN_FREE_BYTES = 30 * (1024**3)
      CHECKS = %i[check_workdir check_container check_manifests check_signing check_network].freeze
      LABELS = { ok: ['ok', :green], warn: ['warn', :yellow], fail: ['fail', :red], skip: ['skip', :dim] }.freeze
      PROBE_TIMEOUT_SEC = 20

      class << self
        def summary
          'check config, workdir, container runtime, image, manifests and signing key'
        end

        def log_file?
          false
        end

        def tolerates_config_error?
          true
        end
      end

      def call
        @failures = 0
        config_error ? report(:fail, 'config', config_error.message) : run_checks
        @failures.zero? ? 0 : 1
      end

      private

      def run_checks
        report(:ok, 'config', config.files.map { |file| relative(file) }.join(' + '))
        CHECKS.each { |name| guarded(name) }
      end

      def guarded(name)
        send(name)
      rescue ::PackmanNova::Error, ::SystemCallError => e
        report(:fail, name.to_s.delete_prefix('check_'), e.message)
      end

      def check_workdir
        workdir = config.workdir
        writable_dir = workdir.existing_ancestor
        return report(:fail, 'workdir', "#{writable_dir} is not writable") unless writable?(writable_dir)

        report(workdir.exist? ? :ok : :warn, 'workdir', workdir.exist? ? "#{workdir.root} writable" : "#{workdir.root} does not exist yet, #{writable_dir} is writable")
        check_disk(workdir.free_bytes)
      end

      def check_disk(free)
        report(free < MIN_FREE_BYTES ? :warn : :ok, 'disk', "#{gigabytes(free)} GB free (warn below #{gigabytes(MIN_FREE_BYTES)} GB)")
      end

      def gigabytes(bytes)
        (bytes / (1024.0**3)).round(1)
      end

      def check_container
        subprocess = ::PackmanNova::Utils::Subprocess.new(logger:)
        runtime = ::PackmanNova::Container::Runtime.detect(config:)
        report(:ok, 'runtime', subprocess.capture([runtime.executable, '--version']).strip)
        image = ::PackmanNova::Container::Image.new(runtime:, config:, logger:, subprocess:, workdir: config.workdir)
        report_image(image)
      end

      def report_image(image)
        return report(:warn, 'image', "#{image.tag} missing; run 'packman-nova image build'") unless image.exists?
        return report(:ok, 'image', "#{image.tag} #{image.id[0, 19]}") if image.up_to_date?

        report(:warn, 'image', "#{image.tag} present but not built from the current #{relative(image.containerfile)}; run 'packman-nova image build'")
      end

      def check_manifests
        loader = ::PackmanNova::Manifest::Loader.new(packages_dir: config.packages_dir)
        loader.errors.each { |error| report(:fail, 'manifest', error.message) }
        report(:warn, 'manifests', "no package.yml in: #{loader.skipped.join(', ')}") unless loader.skipped.empty?
        report_manifest_count(loader.manifests)
      end

      def report_manifest_count(manifests)
        report(manifests.empty? ? :warn : :ok, 'manifests', "#{manifests.size} valid (#{manifests.count(&:enabled?)} enabled)")
      end

      def check_signing
        encoded = config.signing.gpg_private_key_base64
        if encoded.empty?
          report(:warn, 'gpg key', 'GPG_PRIVATE_KEY_BASE64 is not set; publish needs it')
        else
          report_private_key(encoded)
        end
      end

      def report_private_key(encoded)
        return report(:ok, 'gpg key', 'decodes to an armored private key') if ::PackmanNova::Gpg.to_armor(encoded).include?('PRIVATE KEY')

        report(:fail, 'gpg key', 'GPG_PRIVATE_KEY_BASE64 does not decode to an armored PGP private key')
      rescue ::PackmanNova::GpgError => e
        report(:fail, 'gpg key', "GPG_PRIVATE_KEY_BASE64: #{e.message}")
      end

      def check_network
        return report(:skip, 'network', 'offline') if config.offline?

        http = ::PackmanNova::Utils::Http.new(logger:, timeout_sec: PROBE_TIMEOUT_SEC, retries: 0)
        [['obs api', config.prjconf.base_url], ['tw repo', config.distro.snapshot_url]].each { |name, url| probe(http, name, url) }
      end

      def probe(http, name, url)
        report(:ok, name, "#{url} HTTP #{http.head(url).code}")
      rescue ::PackmanNova::DownloadError => e
        report(:fail, name, e.message)
      end

      def writable?(dir)
        probe = ::File.join(dir, ".packman-nova-check-#{::SecureRandom.hex(4)}")
        ::File.write(probe, '')
        ::File.delete(probe)
        true
      rescue ::SystemCallError
        false
      end

      def report(status, name, detail)
        @failures += 1 if status == :fail
        text, color = LABELS.fetch(status)
        label = ::PackmanNova::Utils::Color.enabled?(out) ? ::PackmanNova::Utils::Color.paint(text.ljust(4), color) : text.ljust(4)
        out.puts("#{label}  #{name.ljust(10)} #{detail}")
      end

      def relative(path)
        path.delete_prefix("#{::PackmanNova::Config::PROJECT_ROOT}/")
      end
    end
  end
end
