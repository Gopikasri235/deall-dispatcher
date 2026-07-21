# frozen_string_literal: true

# Provides methods for constructing and processing analytics event parameters
module AnalyticsEventParameters
  extend ActiveSupport::Concern

  private

  # Finds the questionnaire event type or returns the original event
  #
  # @param event [String] The event type
  # @param event_object [Object] The associated event object
  # @return [String] The event type (possibly transformed)
  def find_questionnaire_event(event, event_object)
    event
  end

  # Builds properties for registration_complete event
  #
  # @param customer [Customer] The customer object
  # @param _event_object [Object] The associated event object
  # @return [Hash] Event properties
  def registration_complete_properties(customer, _event_object)
    data = customer_onboarding_details(customer)
    data[:registration_decision] = "approve"
    data
  end

  # Builds properties for registration_decline event
  #
  # @param customer [Customer] The customer object
  # @param _event_object [Object] The associated event object
  # @return [Hash] Event properties
  def registration_decline_properties(customer, _event_object)
    data = customer_onboarding_details(customer)
    data[:registration_decision] = "decline"
    data[:rejection_reason] = customer.rejection_reasons.pluck(:name)
    data
  end

  # Extracts customer onboarding details
  #
  # @param customer [Customer] The customer object
  # @return [Hash] Onboarding details
  def customer_onboarding_details(customer)
    onboarding_details = customer.onboarding_detail
    return {} if onboarding_details.nil?

    data = onboarding_details.slice(:account_created_at, :onboarding_started_at, :verification_started_at,
                                    :verification_last_retry_at, :verification_last_failed_at, :onboarded_at,
                                    :retries_left, :rejected_at)
    data[:approved_by] = onboarding_details.approved_by
    data
  end

  # Booster properties for user
  #
  # @param _customer [Customer] The customer object
  # @return [Hash] Booster properties
  def booster_properties(_customer)
    {}
  end

  # Referral properties for user
  #
  # @param _customer [Customer] The customer object
  # @return [Hash] Referral properties
  def referral_properties(_customer)
    {}
  end

  # Questionnaire user properties
  #
  # @param _customer [Customer] The customer object
  # @return [Hash] Questionnaire properties
  def questionnaire_user_properties(_customer)
    {}
  end

  # Calculates age from birthdate
  #
  # @param birthdate [Date] The date of birth
  # @return [Integer, nil] The calculated age
  def calculate_age(birthdate)
    return nil if birthdate.nil?

    age = Date.today.year - birthdate.year
    age -= 1 if Date.today < birthdate + age.years
    age
  end
end
