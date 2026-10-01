module StoreApi
  module V1
    class OrdersController < ActionController::API
      def create
        order = params[:order]
        unless order.is_a?(ActionController::Parameters) && order[:order_number].present?
          return render json: { errors: ["order_number is required"] }, status: :unprocessable_entity
        end

        render json: { order: { order_number: order[:order_number], status: "accepted" } }, status: :created
      end
    end
  end
end
