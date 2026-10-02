# frozen_string_literal: true

require 'fileutils'

module PackmanNova
  module Repo
    class S3Bucket
      DELETE_BATCH = 1000

      attr_reader :name, :prefix

      def initialize(client:, name:, prefix: '')
        @client = client
        @name = name
        @prefix = prefix.to_s.delete_prefix('/').delete_suffix('/')
      end

      def list(sub_prefix = '')
        client.list_objects_v2(bucket: name, prefix: full_key(sub_prefix)).each_with_object({}) do |page, acc|
          page.contents.each { |object| acc[relative(object.key)] = { size: object.size, etag: object.etag.to_s.delete('"') } }
        end
      end

      def download(key, path)
        ::FileUtils.mkdir_p(::File.dirname(path))
        part = "#{path}.part"
        client.get_object(bucket: name, key: full_key(key), response_target: part)
        ::File.rename(part, path)
        path
      ensure
        ::FileUtils.rm_f(part) if part
      end

      def upload(path, key, content_type: ::PackmanNova::Repo::UploadOrder.content_type(key))
        ::File.open(path, 'rb') { |io| client.put_object(bucket: name, key: full_key(key), body: io, content_type: content_type) }
        key
      end

      def delete(keys)
        keys.each_slice(DELETE_BATCH) do |batch|
          client.delete_objects(bucket: name, delete: { objects: batch.map { |key| { key: full_key(key) } }, quiet: true })
        end
        keys
      end

      def exist?(key)
        list(key).key?(key)
      end

      def full_key(key)
        [prefix, key].reject(&:empty?).join('/')
      end

      def url
        "s3://#{name}/#{prefix}"
      end

      private

      attr_reader :client

      def relative(full)
        prefix.empty? ? full : full.delete_prefix("#{prefix}/")
      end
    end
  end
end
