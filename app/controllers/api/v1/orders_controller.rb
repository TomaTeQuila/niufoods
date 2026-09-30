module Api
  module V1
    class OrdersController < ApplicationController
      def index
        orders = Order.where(deleted_at: nil).includes(:order_items).order(:id)
        render json: { orders: orders.map { |order| serialize(order) } }
      end

      def show
        order = Order.where(deleted_at: nil).includes(:order_items).find_by(id: params[:id])
        return head :not_found unless order

        render json: { order: serialize(order) }
      end

      def create
        key = request.headers["Idempotency-Key"].to_s.strip
        return render json: { errors: ["Idempotency-Key header is required"] }, status: :unprocessable_entity if key.empty?

        result = OrderCreator.call(idempotency_key: key, attributes: order_params)
        return render json: { order: serialize(result.order) }, status: result.replayed ? :ok : :created if result.order.persisted?

        render json: { errors: result.order.errors.full_messages }, status: :unprocessable_entity
      end

      def destroy
        order = Order.where(deleted_at: nil).find_by(id: params[:id])
        return head :not_found unless order

        order.update!(deleted_at: Time.current)
        head :no_content
      end

      private

      def order_params
        params.require(:order).permit(:restaurant_id, :order_type, :customer_name, :customer_phone,
                                      :delivery_address, items: %i[product_id quantity]).to_h.symbolize_keys
      rescue ActionController::ParameterMissing
        {}
      end

      def serialize(order)
        {
          id: order.id,
          order_number: order.order_number,
          restaurant_id: order.restaurant_id,
          order_type: order.order_type,
          customer_name: order.customer_name,
          customer_phone: order.customer_phone,
          delivery_address: order.delivery_address,
          total_clp: order.total_clp,
          dispatch_status: order.dispatch_status,
          created_at: order.created_at,
          order_items: order.order_items.map do |item|
            {
              id: item.id,
              product_id: item.product_id,
              quantity: item.quantity,
              unit_price_clp: item.unit_price_clp,
              subtotal_clp: item.subtotal_clp
            }
          end
        }
      end
    end
  end
end
