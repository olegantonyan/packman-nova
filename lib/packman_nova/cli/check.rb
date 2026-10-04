# frozen_string_literal: true

require 'base64'
require 'securerandom'

module PackmanNova
  class Cli
    class Check < ::PackmanNova::Cli::Command
      MIN_FREE_BYTES = 30 * (1024**3)
      ARMORED_PRIVATE_KEY_HEADER = '-----BEGIN PGP PRIVATE KEY BLOCK-----'
      CHECKS = %i[check_workdir check_container check_manifests check_signing check_network].freeze

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
        @reporter = ::PackmanNova::Cli::Report.new(out: out)
        config_error ? report(:fail, 'config', config_error.message) : run_checks
        reporter.failures.zero? ? 0 : 1
      end

      private

      attr_reader :reporter

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
        subprocess = ::PackmanNova::Utils::Subprocess.new(logger: logger)
        runtime = ::PackmanNova::Container::Runtime.detect(config: config)
        report(:ok, 'runtime', subprocess.capture([runtime.executable, '--version']).strip)
        image = ::PackmanNova::Container::Image.new(runtime: runtime, config: config, logger: logger, subprocess: subprocess, workdir: config.workdir)
        report_image(image)
      end

      def report_image(image)
        return report(:warn, 'image', "#{image.tag} missing; run 'packman-nova image build'") unless image.exists?
        return report(:ok, 'image', "#{image.tag} #{image.id[0, 19]}") if image.up_to_date?

        report(:warn, 'image', "#{image.tag} present but not built from the current #{relative(image.containerfile)}; run 'packman-nova image build'")
      end

      def check_manifests
        loader = ::PackmanNova::Manifest::Loader.new(packages_dir: config.resolve('packages'))
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
        decoded = ::Base64.strict_decode64(encoded.gsub(/\s+/, ''))
        return report(:ok, 'gpg key', 'decodes to an armored private key') if decoded.include?(ARMORED_PRIVATE_KEY_HEADER)

        report(:fail, 'gpg key', 'GPG_PRIVATE_KEY_BASE64 does not decode to an armored PGP private key')
      rescue ::ArgumentError
        report(:fail, 'gpg key', 'GPG_PRIVATE_KEY_BASE64 is not valid base64')
      end

      def check_network
        return report(:skip, 'network', 'offline') if config.offline?

        ::PackmanNova::Sources::Reachability.new(config: config, logger: logger).call.each { |result| report(*result) }
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
        reporter.call(status, name, detail)
      end

      def relative(path)
        path.delete_prefix("#{config&.project_root || ::PackmanNova::Config::PROJECT_ROOT}/")
      end
    end
  end
end
