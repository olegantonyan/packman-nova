# frozen_string_literal: true

require 'test_helper'

describe ::PackmanNova::Repo::UploadOrder do
  it 'orders rpms, repodata, repomd, repomd signature and key, then the small files' do
    keys = %w[
      packman-nova.key packages.json index.html p/state.json p/packman-nova.repo
      p/x86_64/repodata/repomd.xml.key p/x86_64/repodata/repomd.xml.asc p/x86_64/repodata/repomd.xml
      p/x86_64/repodata/abc-primary.xml.zst p/src/a.src.rpm p/x86_64/a.x86_64.rpm style.css
    ]

    assert_equal %w[
      p/src/a.src.rpm p/x86_64/a.x86_64.rpm p/x86_64/repodata/abc-primary.xml.zst p/x86_64/repodata/repomd.xml
      p/x86_64/repodata/repomd.xml.asc p/x86_64/repodata/repomd.xml.key p/packman-nova.repo p/state.json
      style.css index.html packages.json packman-nova.key
    ], ::PackmanNova::Repo::UploadOrder.sort(keys)
  end

  it 'maps content types' do
    assert_equal 'application/x-rpm', ::PackmanNova::Repo::UploadOrder.content_type('a.rpm')
    assert_equal 'text/html; charset=utf-8', ::PackmanNova::Repo::UploadOrder.content_type('index.html')
    assert_equal 'application/octet-stream', ::PackmanNova::Repo::UploadOrder.content_type('blob')
  end
end
