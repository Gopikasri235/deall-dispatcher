# frozen_string_literal: true

# Sidekiq Job to log user behaviour data to amplitude
class AmplitudeLogger
  include Sidekiq::Job
  include AsyncJobLogging
  include AnalyticsEventParameters
  sidekiq_options retry: 1

  def perform(params)
    log_for_job(jid, "amplitude_logger")
    Rails.logger.info("#{params} - From amplitude worker. Job ID: #{jid}")
    event, customer_id, event_object_id, event_object_class, upload_source, event_source = params.values

    customer = Customer.find(customer_id)
    # Remove below 2 lines while sending the event to amplitude
    Rails.logger.info("Customer: #{customer.to_json} - From amplitude worker. Job ID: #{jid} Processed")
    return ""

    # Migrated existing code, Require dev testing
    event_object_class = begin
      event_object_class.constantize
    rescue StandardError
      nil
    end

    if event_object_id.present? && event_object_class.present?
      event_object = event_object_class.find_by(id: event_object_id)
    end

    data = construct_request_body(event, customer, event_object, upload_source, event_source)

    if Flipper.enabled?(:lambda_logger)
      AWS_SQS.send_message(
        queue_url: Rails.application.credentials.sqs_logger_events_url,
        message_body: sqs_data_payload(data)
      )
    else
      response = RestClientService.new({ method: "post", url: amplitude_url, request_body: data, headers: {} }).perform
      Rails.logger.info("#{response} - From amplitude worker. Job ID: #{jid}")
    end

    # If event Source is Rise Point, push event to existing project and new project
    if event_source == "RisePoint"
      data[:api_key] = rise_api_key
      if Flipper.enabled?(:lambda_logger)
        AWS_SQS.send_message(
          queue_url: Rails.application.credentials.sqs_logger_events_url,
          message_body: sqs_data_payload(data)
        )
      else
        response = RestClientService.new({ method: "post", url: amplitude_url, request_body: data,
                                           headers: {} }).perform
        Rails.logger.info("RisePoint: #{response} - From amplitude worker. Job ID: #{jid}")
      end
    end
    log_for_job(jid, "amplitude_logger")
  end

  private

  def amplitude_url
    Rails.application.credentials.amplitude_url
  end

  def sqs_data_payload(data)
    {
      logger: "amplitude",
      data: data
    }.to_json
  end

  def construct_request_body(event, customer, event_object, upload_source, event_source)
    data = {}
    event_data = {}
    data.merge!(api_key: api_key, options: event_options)
    event_data.merge!(basic_event_details(event, customer, event_object))
    event_data.merge!(event_properties: event_properties(event, customer, event_object, event_source))
    event_data.merge!(user_properties: user_properties(event, customer, upload_source))
    data.merge!(events: [ event_data ])
    data
  end

  def basic_event_details(event, customer, event_object)
    event = find_questionnaire_event(event, event_object)
    data = { event_type: event, user_id: customer.id, time: Time.now.to_i }
    device = customer.devices.order(created_at: :desc).first
    data.merge!(platform: device.platform) if device.present?
    data
  end

  def event_properties(event, customer, event_object, event_source)
    data = send("#{event}_properties", customer, event_object)
    data[:event_source] = event_source
    data
  end

  def user_properties(_event, customer, upload_source)
    details = booster_properties(customer)
    details.merge!(referral_properties(customer))
    details.merge!(questionnaire_user_properties(customer))
    {
      date_of_birth: customer.customer_detail.date_of_birth,
      age: calculate_age(customer.customer_detail.date_of_birth),
      first_name: customer.first_name,
      last_name: customer.last_name,
      full_name: customer.full_name,
      job_title: customer.customer_detail.job_title,
      marital_status: customer.customer_detail.marital_status,
      religion: customer.customer_detail.religion,
      sex: customer.customer_detail.gender,
      booster_status: customer&.active_plan&.name,
      upload_source: upload_source,
      id_address: customer.customer_detail.address,
      id_neighbourhood: customer.customer_detail.neighbourhood&.zone_keyword,
      acquisition_channel: customer.customer_detail.acquisition_channel,
      utm_source: customer.onboarding_detail&.media_source,    # used existing key
      utm_medium: customer.onboarding_detail&.utm_medium,
      utm_campaign: customer.onboarding_detail&.campaign,    # used existing key
      utm_term: customer.onboarding_detail&.utm_term,
      utm_content: customer.onboarding_detail&.utm_content,
      iscore: customer.customer_iscore&.score,
      initial_purchasing_power: customer.initial_purchasing_power,
      random_approval: customer.onboarding_detail&.auto_approved? ? "Random" : "Not Random"
    }.merge(details)
  end

  def event_options
    { min_id_length: 1 }
  end

  def api_key
    Rails.application.credentials.amplitude_api_key
  end

  def rise_api_key
    Rails.application.credentials.amplitude_rise_api_key
  end
end
