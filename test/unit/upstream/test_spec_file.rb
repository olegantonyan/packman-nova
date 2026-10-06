# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Upstream::SpecFile do
  let(:spec) do
    ::PackmanNova::Upstream::SpecFile.new(<<~SPEC)
      %define sover   215
      %global fversion 5.15.285-5.15.010.0
      Name:           pkg
      Version:        5.15.285+5.15.010.0
      Source0:        https://example.org/pkg_%{fversion}.orig.tar.gz
      Source1:        pkg-5.15.285-5.15.010.0-extra.tar
      Provides:       weakremover(libpkg-209)
      Provides:       weakremover(libpkg-199)
      Requires:       other >= 5.15.285-5.15.010.0
    SPEC
  end

  it 'reads Version and sover' do
    assert_equal '5.15.285+5.15.010.0', spec.version
    assert_equal '215', spec.sover
  end

  it 'rewrites Version (rpm form) and versioned define and Source lines only' do
    content = spec.with_version('5.15.285-5.15.010.0', '5.16.1-5.16.0.0').content

    assert_includes content, "Version:        5.16.1+5.16.0.0\n"
    assert_includes content, "%global fversion 5.16.1-5.16.0.0\n"
    assert_includes content, "Source1:        pkg-5.16.1-5.16.0.0-extra.tar\n"
    assert_includes content, "Requires:       other >= 5.15.285-5.15.010.0\n"
  end

  it 'bumps sover and records the old one as weakremover' do
    content = spec.with_sover('215', '216').content

    assert_includes content, "%define sover   216\n"
    assert_includes content, "Provides:       weakremover(libpkg-215)\nProvides:       weakremover(libpkg-209)\n"
    assert_equal content, ::PackmanNova::Upstream::SpecFile.new(content).with_sover('215', '216').content
  end
end

describe ::PackmanNova::Upstream::VersionText do
  it 'replaces whole versions only' do
    text = 'pkg-1.5.tar pkg-1.50.tar v1.5/x 11.5'

    assert_equal 'pkg-1.6.tar pkg-1.50.tar v1.6/x 11.5', ::PackmanNova::Upstream::VersionText.replace(text, '1.5', '1.6')
    refute ::PackmanNova::Upstream::VersionText.mentions?('pkg-1.50.tar', '1.5')
  end
end
