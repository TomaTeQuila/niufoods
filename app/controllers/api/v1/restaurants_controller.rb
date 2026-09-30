module Api
  module V1
    class RestaurantsController < ActionController::API
      REPLACEMENT_FIELDS = %w[name code dispatch_url active].freeze
      RESPONSE_FIELDS = %i[id name code dispatch_url active created_at updated_at].freeze

      before_action :set_restaurant, only: %i[show update destroy]

      def index
        render json: Restaurant.where(deleted_at: nil).order(:id).map { |restaurant| restaurant_json(restaurant) }
      end

      def show
        render json: restaurant_json(@restaurant)
      end

      def create
        restaurant = Restaurant.new(create_params)
        if restaurant.save
          render json: restaurant_json(restaurant), status: :created
        else
          render json: { errors: restaurant.errors.to_hash }, status: :unprocessable_entity
        end
      end

      def update
        attributes = replacement_params
        return render_incomplete_replacement unless attributes

        if @restaurant.update(attributes)
          render json: restaurant_json(@restaurant)
        else
          render json: { errors: @restaurant.errors.to_hash }, status: :unprocessable_entity
        end
      end

      def destroy
        @restaurant.update!(deleted_at: Time.current)
        head :no_content
      end

      private

      def set_restaurant
        @restaurant = Restaurant.where(deleted_at: nil).find_by(id: params[:id])
        head :not_found unless @restaurant
      end

      def create_params
        params.require(:restaurant).permit(:name, :code, :dispatch_url)
      end

      def replacement_params
        values = params.require(:restaurant)
        return unless REPLACEMENT_FIELDS.all? { |field| values.key?(field) }

        values.permit(*REPLACEMENT_FIELDS)
      end

      def render_incomplete_replacement
        render json: { errors: { base: ["must include name, code, dispatch_url, and active"] } },
               status: :unprocessable_entity
      end

      def restaurant_json(restaurant)
        restaurant.as_json(only: RESPONSE_FIELDS)
      end
    end
  end
end
