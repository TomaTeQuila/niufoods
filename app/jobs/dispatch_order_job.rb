class DispatchOrderJob
  include Sidekiq::Job

  sidekiq_options retry: 5

  sidekiq_retries_exhausted do |job, exception|
    mark_failed(job.fetch("args").first, exception&.message || "Dispatch retries exhausted")
  end

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order&.dispatch_status == "pending"

    result = order.with_lock do
      next unless order.dispatch_status == "pending"

      order.update!(dispatch_attempts: order.dispatch_attempts + 1)
      dispatch_result = DispatchClient.call(order)
      if dispatch_result == :sent
        order.update!(dispatch_status: "sent", dispatched_at: Time.current, last_dispatch_error: nil)
      else
        order.update!(last_dispatch_error: dispatch_result.error)
        order.update!(dispatch_status: "error") if dispatch_result.status == :error
      end
      dispatch_result
    end

    raise DispatchClient::RetryableError, result.error if result.respond_to?(:status) && result.status == :retry
  end

  def self.mark_failed(order_id, error)
    order = Order.find_by(id: order_id)
    order&.update!(dispatch_status: "error", last_dispatch_error: error.to_s)
  end
end
