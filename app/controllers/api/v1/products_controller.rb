module Api
  module V1
    class ProductsController < ActionController::API
      REPLACEMENT_FIELDS = %w[name sku price_clp active].freeze
      RESPONSE_FIELDS = %i[id name sku price_clp active created_at updated_at].freeze

      before_action :set_product, only: %i[show update destroy]

      def index
        render json: Product.where(deleted_at: nil).order(:id).map { |product| product_json(product) }
      end

      def show
        render json: product_json(@product)
      end

      def create
        attributes = create_params
        return render_invalid_price unless integer_price?(attributes[:price_clp])

        product = Product.new(attributes)
        if product.save
          render json: product_json(product), status: :created
        else
          render json: { errors: product.errors.to_hash }, status: :unprocessable_entity
        end
      end

      def update
        attributes = replacement_params
        return render_incomplete_replacement unless attributes
        return render_invalid_price unless integer_price?(attributes[:price_clp])

        if @product.update(attributes)
          render json: product_json(@product)
        else
          render json: { errors: @product.errors.to_hash }, status: :unprocessable_entity
        end
      end

      def destroy
        @product.update!(deleted_at: Time.current)
        head :no_content
      end

      private

      def set_product
        @product = Product.where(deleted_at: nil).find_by(id: params[:id])
        head :not_found unless @product
      end

      def create_params
        params.require(:product).permit(:name, :sku, :price_clp)
      end

      def replacement_params
        values = params.require(:product)
        return unless REPLACEMENT_FIELDS.all? { |field| values.key?(field) }

        values.permit(*REPLACEMENT_FIELDS)
      end

      def integer_price?(value)
        value.to_s.match?(/\A\d+\z/)
      end

      def render_invalid_price
        render json: { errors: { price_clp: ["must be an integer"] } }, status: :unprocessable_entity
      end

      def render_incomplete_replacement
        render json: { errors: { base: ["must include name, sku, price_clp, and active"] } },
               status: :unprocessable_entity
      end

      def product_json(product)
        product.as_json(only: RESPONSE_FIELDS)
      end
    end
  end
end
