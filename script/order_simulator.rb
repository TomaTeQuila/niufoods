#!/usr/bin/env ruby

require "json"
require "net/http"
require "securerandom"
require "uri"

class OrderSimulator
  RESTAURANT_IDS = [1, 2, 3].freeze
  PRODUCT_IDS = (1..10).to_a.freeze
  ORDER_TYPES = %w[pickup delivery].freeze
  Result = Struct.new(:status, :http_status, :details, keyword_init: true)

  def initialize(endpoint:, http: Net::HTTP, random: Random.new)
    @endpoint = URI(endpoint)
    @http = http
    @random = random
  end

  def run(count:)
    Array.new(count) { submit_order }
  end

  private

  def submit_order
    key = "order-simulator-#{SecureRandom.uuid}"
    response = @http.post(
      @endpoint,
      JSON.generate(order: build_order),
      { "Content-Type" => "application/json", "Idempotency-Key" => key }
    )
    status = response.code.to_i
    Result.new(
      status: result_status(status),
      http_status: status,
      details: parse_body(response.body)
    )
  rescue StandardError => error
    Result.new(status: :transport_error, details: error.message)
  end

  def build_order
    {
      restaurant_id: RESTAURANT_IDS.sample(random: @random),
      order_type: ORDER_TYPES.sample(random: @random),
      customer_name: "Simulator Customer",
      customer_phone: "+56912345678",
      delivery_address: "Av. Providencia 1234, Santiago",
      items: PRODUCT_IDS.sample(@random.rand(1..3), random: @random).map do |product_id|
        { product_id: product_id, quantity: @random.rand(1..5) }
      end
    }
  end

  def result_status(http_status)
    return :success if http_status.between?(200, 299)
    return :validation_error if http_status.between?(400, 499)

    :http_error
  end

  def parse_body(body)
    JSON.parse(body)
  rescue JSON::ParserError
    body
  end
end

if $PROGRAM_NAME == __FILE__
  require "optparse"

  options = { count: 5, endpoint: "http://localhost:3000/api/v1/orders" }
  OptionParser.new do |parser|
    parser.banner = "Usage: ruby script/order_simulator.rb [options]"
    parser.on("-n", "--count COUNT", Integer, "Number of orders to send (default: 5)") { |count| options[:count] = count }
    parser.on("-u", "--url URL", "Orders API URL") { |url| options[:endpoint] = url }
  end.parse!

  abort "Count must be greater than zero" unless options[:count].positive?

  results = OrderSimulator.new(endpoint: options[:endpoint]).run(count: options[:count])
  results.each_with_index do |result, index|
    puts "Order #{index + 1}: #{result.status} (HTTP #{result.http_status || 'no response'}) - #{result.details}"
  end
end
