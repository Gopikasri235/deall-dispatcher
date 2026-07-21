# frozen_string_literal: true

module Api
  module V1
    # Receives analytics events and enqueues them to Amplitude logger
    class AnalyticsController < ApplicationController

      def create
        Rails.logger.info("Received analytics event: #{analytics_event_params.as_json}")
        job_id = AmplitudeLogger.perform_async(analytics_event_params.as_json)

        render json: {
          success: true,
          job_id: job_id,
          message: "Event enqueued for processing"
        }, status: :accepted
      end

      private
      # Permitted parameters for analytics events
      def analytics_event_params
        params.require(:analytic).permit(:event, :customer_id, :event_object_id, :event_object_class, :upload_source, :event_source)
      end
    end
  end
end
