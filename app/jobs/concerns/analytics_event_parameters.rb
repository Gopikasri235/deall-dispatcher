module AnalyticsEventParameters
  def find_questionnaire_event(event, event_object)
    return event unless event_object.class.name == "QuestionnaireResponse"

    "question_#{event_object.question.event_name}"
  end

  def booster_properties(customer)
    plan_actions = customer.customer_plan_actions
    referral_action = PlanAction.find_by("action ILIKE ?", "%referrals%")
    purchase_action_ids = PlanAction.where("action ILIKE ?", "%Complete payment%").ids
    docs_uploaded = customer.customer_attachments
                                                .where(attachment_type: BOOSTER_DOCUMENTS.values.flatten.uniq)
                                                .pluck(:attachment_type)
                                                .map { |doc_type| doc_type.camelize }
                                                .uniq.join(", ")
    {
      referral_criteria: booster_referral_check(plan_actions, referral_action),
      purchase_completion_criteria: booster_purchase_status(plan_actions, purchase_action_ids),
      docs_uploaded: docs_uploaded.presence || "None"
    }
  rescue
    {}
  end

  def booster_referral_check(plan_actions, referral_action)
    plan_actions.find_by(plan_action_id: referral_action.id).completed? ? "Yes" : "No"
  end

  def booster_purchase_status(plan_actions, purchase_action_ids)
    case plan_actions.where(plan_action_id: purchase_action_ids).completed.count
    when 1 then "Silver"
    when 2 then "Gold"
    end
  end

  def referral_properties(customer)
    referral_metrics = customer.referral_rewards_metrics
    {
      referees_signup: referral_metrics[:accepted_invite],
      referees_purchased: referral_metrics[:no_of_friends_made_purchase],
      referees_complete: referral_metrics[:no_of_friends_made_payment]
    }
  rescue
    {}
  end

  def questionnaire_user_properties(customer)
    responses = customer.questionnaire_responses.onboarding.map do |response|
      if response.question.event_name == "address" || response.question.question_type == "multiple"
        begin
          response.fetch_answers.first.map.each do |key, value|
            { "question_#{key}": value }
          end.compact.reduce({}, :merge)
        rescue
          { "question_#{response.question.event_name}": response.fetch_answers.first }
        end
      else
        { "question_#{response.question.event_name}": response.fetch_answers.join(", ") }
      end
    end
    responses.reduce({}, :merge)
  rescue
    {}
  end
end
