require "net/http"
require "json"

class DispatchClient
  Result = Struct.new(:status, :error, keyword_init: true)

  class RetryableError < StandardError; end

  RETRYABLE_HTTP_CODES = [408, 425, 429].freeze

  def self.call(order)
    new(order).call
  end

  def initialize(order)
    @order = order
  end

  def call
    uri = URI(endpoint)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Idempotency-Key"] = @order.order_number
    request.body = JSON.generate(payload)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                               open_timeout: 3, read_timeout: 5) do |http|
      http.request(request)
    end

    classify_response(response)
  rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, Errno::ECONNREFUSED,
         Errno::ECONNRESET, EOFError, IOError, Timeout::Error => error
    Result.new(status: :retry, error: error.message)
  rescue URI::InvalidURIError => error
    Result.new(status: :error, error: "Invalid dispatch URL: #{error.message}")
  end

  private

  def endpoint
    @order.restaurant.dispatch_url.presence || ENV.fetch("STORE_API_URL", "http://localhost:3000/store_api/v1/orders")
  end

  def payload
    {
      order: {
        order_number: @order.order_number,
        restaurant: { code: @order.restaurant.code },
        order_type: @order.order_type,
        customer_name: @order.customer_name,
        customer_phone: @order.customer_phone,
        delivery_address: @order.delivery_address,
        total_clp: @order.total_clp,
        items: @order.order_items.map do |item|
          { product_id: item.product_id, quantity: item.quantity,
            unit_price_clp: item.unit_price_clp, subtotal_clp: item.subtotal_clp }
        end
      }
    }
  end

  def classify_response(response)
    code = response.code.to_i
    return :sent if code.between?(200, 299)

    message = "HTTP #{code}: #{response.message}"
    message = "#{message} - #{response.body}" if response.body.present?
    status = code >= 500 || RETRYABLE_HTTP_CODES.include?(code) ? :retry : :error
    Result.new(status:, error: message)
  end
end
