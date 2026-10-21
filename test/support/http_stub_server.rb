# frozen_string_literal: true

require 'socket'

class HttpStubServer
  Response = ::Data.define(:status, :headers, :body, :ranges)
  RANGE = /\ARange:\s*bytes=(\d+)-(\d+)/i

  attr_reader :requests

  def initialize
    @server = ::TCPServer.new('127.0.0.1', 0)
    @routes = ::Hash.new { |hash, key| hash[key] = [] }
    @requests = ::Queue.new
    @thread = ::Thread.new { serve }
  end

  def url(path)
    "http://127.0.0.1:#{server.addr[1]}#{path}"
  end

  def on(path, status: 200, headers: {}, body: '', ranges: true)
    routes[path] << Response.new(status:, headers:, body:, ranges:)
    self
  end

  def stop
    thread.kill
    server.close
  end

  private

  attr_reader :server, :routes, :thread

  def serve
    loop do
      client = server.accept
      handle(client)
    ensure
      client&.close
    end
  end

  def handle(client)
    method, path = client.gets.to_s.split
    range = read_range(client)
    requests << [method, path]
    client.write(render(partial(next_response(path), range), method))
  end

  def read_range(client)
    range = nil
    while (line = client.gets.to_s.strip) && !line.empty?
      first, last = line.match(RANGE)&.captures&.map(&:to_i)
      range = first..last if first
    end
    range
  end

  def partial(response, range)
    return response unless range && response.ranges && response.status == 200

    response.with(status: 206, body: response.body.byteslice(range))
  end

  def next_response(path)
    queue = routes[path]
    return Response.new(status: 404, headers: {}, body: 'not found', ranges: false) if queue.empty?

    queue.size > 1 ? queue.shift : queue.first
  end

  def render(response, method)
    headers = { 'Content-Length' => response.body.bytesize, 'Connection' => 'close' }.merge(response.headers)
    head = ["HTTP/1.1 #{response.status} X", *headers.map { |key, value| "#{key}: #{value}" }].join("\r\n")
    "#{head}\r\n\r\n#{response.body unless method == 'HEAD'}"
  end
end
