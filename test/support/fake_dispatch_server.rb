require "socket"

class FakeDispatchServer
  def request_text
    @thread&.join
    @request_text
  end

  def initialize(status:)
    @status = status
  end

  def run
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    @thread = Thread.new do
      socket = server.accept
      headers = +""
      headers << socket.gets until headers.end_with?("\r\n\r\n")
      content_length = headers[/Content-Length:\s*(\d+)/i, 1].to_i
      body = socket.read(content_length)
      @request_text = headers + body
      phrase = Rack::Utils::HTTP_STATUS_CODES.fetch(@status)
      response_body = { order: { status: "accepted" } }.to_json
      socket.write("HTTP/1.1 #{@status} #{phrase}\r\nContent-Type: application/json\r\nContent-Length: #{response_body.bytesize}\r\nConnection: close\r\n\r\n#{response_body}")
      socket.close
    ensure
      server.close
    end
    yield("http://127.0.0.1:#{port}/store_api/v1/orders", self)
  ensure
    @thread&.join
  end
end
