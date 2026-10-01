require "test_helper"
require_relative "../../script/order_simulator"

class OrderSimulatorTest < ActiveSupport::TestCase
  class FakeResponse
    attr_reader :code, :body

    def initialize(code, body)
      @code = code.to_s
      @body = body
    end
  end

  class FakeHttp
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def post(uri, body, headers)
      @requests << { uri: uri, body: JSON.parse(body), headers: headers }
      @responses.shift
    end
  end

  test "posts seeded-style order payload and records success and validation errors without aborting" do
    http = FakeHttp.new([
      FakeResponse.new(201, '{"order":{"id":1}}'),
      FakeResponse.new(422, %q({"errors":["Customer name can't be blank"]}))
    ])
    simulator = OrderSimulator.new(
      endpoint: "http://localhost:3000/api/v1/orders",
      http: http,
      random: Random.new(7)
    )

    results = simulator.run(count: 2)

    assert_equal %i[success validation_error], results.map(&:status)
    assert_equal 2, http.requests.length
    request = http.requests.first
    assert_equal "http://localhost:3000/api/v1/orders", request[:uri].to_s
    assert_equal "application/json", request[:headers]["Content-Type"]
    assert_match(/\Aorder-simulator-/, request[:headers]["Idempotency-Key"])
    order = request[:body].fetch("order")
    assert_includes [1, 2, 3], order.fetch("restaurant_id")
    assert_includes %w[pickup delivery], order.fetch("order_type")
    assert_operator order.fetch("items").length, :>=, 1
    assert order.fetch("items").all? { |item| item["quantity"].between?(1, 5) }
  end
end
