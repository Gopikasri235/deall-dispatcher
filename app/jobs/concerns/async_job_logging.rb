# frozen_string_literal: true

# Provides logging utilities for asynchronous jobs
module AsyncJobLogging
  extend ActiveSupport::Concern

  # Logs job execution details
  #
  # @param job_id [String] The unique ID of the job
  # @param job_name [String] The name/type of the job
  def log_for_job(job_id, job_name)
    Rails.logger.info("Job #{job_name} (ID: #{job_id}) - Processing")
  end
end
