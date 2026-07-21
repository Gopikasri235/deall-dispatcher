# frozen_string_literal: true

module Api
  module V1
    class ApplicationController < ActionController::API
      include ActionController::MimeResponds

      rescue_from StandardError, with: :handle_error

      protected

      def handle_error(exception)
        Rails.logger.error("API Error: #{exception.message}")
        Rails.logger.error(exception.backtrace.join("\n"))

        render json: {
          error: "Internal server error",
          message: exception.message
        }, status: :internal_server_error
      end
    end
  end
end
