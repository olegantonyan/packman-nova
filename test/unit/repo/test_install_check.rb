# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Repo::InstallCheck do
  let(:tmp) { ::Dir.mktmpdir('packman-nova-installcheck-') }
  let(:layout) { ::PackmanNova::Repo::Layout.new(root: ::File.join(tmp, 'repo'), path: 'p') }
  let(:workdir) { ::PackmanNova::Workdir.new(root: ::File.join(tmp, 'wd')).prepare! }
  let(:output) do
    <<~OUT
      can't install libavcodec62-32bit-8.1.2-1699.8.nova.1.x86_64:
        nothing provides liboapv.so.1 needed by libavcodec62-32bit-8.1.2-1699.8.nova.1.x86_64
      can't install libavformat62-32bit-8.1.2-1699.8.nova.1.x86_64:
        package libavformat62-32bit-8.1.2-1699.8.nova.1.x86_64 requires libavcodec.so.62, but none of the providers can be installed
        nothing provides liboapv.so.1 needed by libavcodec62-32bit-8.1.2-1699.8.nova.1.x86_64
      can't install libavfilter7_110-32bit-4.4.8-1699.8.nova.1.x86_64:
        package libavfilter7_110-32bit-4.4.8-1699.8.nova.1.x86_64 requires libavcodec.so.58.134, but none of the providers can be installed
        nothing provides libcelt0.so.2 needed by libavcodec58_134-32bit-4.4.8-1699.8.nova.1.x86_64
    OUT
  end
  let(:toolbox) { InstallCheckFakes::Toolbox.new(output) }
  let(:check) do
    ::PackmanNova::Repo::InstallCheck.new(toolbox:, downloader: InstallCheckFakes::Downloader.new, workdir:, logger: null_logger, allow_missing: %w[libcelt0.so.2])
  end
  let(:entry) { ::PackmanNova::Repo::BuildOutputs::Entry }

  before do
    ::FileUtils.mkdir_p(layout.repodata_dir('x86_64'))
    ::File.write(layout.repomd('x86_64'), InstallCheckFakes.repomd('repodata/ours-primary.xml.zst'))
  end

  after { ::FileUtils.rm_rf(tmp) }

  def desired(*rpms)
    rpms.to_h { |rpm, package| ["x86_64/#{rpm}.rpm", entry.new(relative: "x86_64/#{rpm}.rpm", package:, source: '/r', source_sha256: 's')] }
  end

  it 'checks our primary against the downloaded distro primaries' do
    check.call(layout:, arch: 'x86_64', repos: ['https://tw.example/oss/'])

    assert_equal ['x86_64', '/repo/x86_64/repodata/ours-primary.xml.zst', '--nocheck', '/distro/0-tw-primary.xml.zst'], toolbox.args
    assert_equal 'tw', ::File.read(::File.join(workdir.tmp_dir, 'installcheck', '0-tw-primary.xml.zst'))
  end

  it 'groups root causes by package and skips allowed missing capabilities' do
    problems = check.by_package(
      layout:, arch: 'x86_64', repos: ['https://tw.example/oss'],
      desired: desired(%w[libavcodec62-32bit-8.1.2-1699.8.nova.1.x86_64 ffmpeg-8], %w[libavformat62-32bit-8.1.2-1699.8.nova.1.x86_64 ffmpeg-8])
    )

    assert_equal(
      {
        'ffmpeg-8' => [
          'libavcodec62-32bit: nothing provides liboapv.so.1 needed by libavcodec62-32bit-8.1.2-1699.8.nova.1.x86_64',
          'libavformat62-32bit: nothing provides liboapv.so.1 needed by libavcodec62-32bit-8.1.2-1699.8.nova.1.x86_64'
        ]
      },
      problems
    )
  end
end

module InstallCheckFakes
  module_function

  def repomd(href)
    %(<repomd><data type="other"><location href="repodata/x-other.xml.zst"/></data><data type="primary"><location href="#{href}"/></data></repomd>)
  end

  class Downloader
    def get(_url)
      ::InstallCheckFakes.repomd('repodata/tw-primary.xml.zst')
    end

    def download(_url, path)
      ::File.write(path, 'tw')
    end
  end

  class Toolbox
    attr_reader :args

    def initialize(output)
      @output = output
    end

    def capture(_script, mounts:, args:)
      raise 'mounts missing' unless mounts.map(&:target) == %w[/repo /distro]

      @args = args
      @output
    end
  end
end
