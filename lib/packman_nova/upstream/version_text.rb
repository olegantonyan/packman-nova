# frozen_string_literal: true

module PackmanNova
  class Upstream
    class VersionText
      class << self
        def mentions?(text, version)
          regexp(version).match?(text)
        end

        def replace(text, old_version, new_version)
          text.gsub(regexp(old_version)) { new_version }
        end

        def rpm(version)
          version.tr('-', '+')
        end

        private

        def regexp(version)
          /(?<![\d.])#{::Regexp.escape(version)}(?!\d)/
        end
      end
    end
  end
end
