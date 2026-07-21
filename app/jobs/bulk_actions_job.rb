class BulkActionsJob < ApplicationJob
  include DateRangeHelper

  queue_as :medium
  attr_accessor :records

  MODEL_TYPE = ['Conversation'].freeze

  def perform(account:, params:, user:)
    @account = account
    @user = user
    Current.user = user
    @params = params
    @records = records_to_updated(params[:ids])
    bulk_update
  ensure
    Current.reset
  end

  def bulk_update
    bulk_conversation_update
    bulk_remove_labels
  end

  def bulk_conversation_update
    params = available_params(@params) || {}
    records.each do |conversation|
      bulk_snoozed_until(conversation)
      bulk_add_labels(conversation)

      was_spam = conversation.is_spam
      was_blacklisted = conversation.is_blacklisted

      conversation.update!(params) if params.present?

      cancel_follow_up_job_if_newly_flagged(conversation, was_spam, was_blacklisted)
    end
  end

  def cancel_follow_up_job_if_newly_flagged(conversation, was_spam, was_blacklisted)
    return if conversation.follow_up_jid.blank?
    return unless (!was_spam && conversation.is_spam) || (!was_blacklisted && conversation.is_blacklisted)

    conversation.cancel_existing_follow_up_job
  end

  def bulk_remove_labels
    records.each do |conversation|
      remove_labels(conversation)
    end
  end

  def available_params(params)
    fields = params[:fields].to_h

    fields.delete('status') if fields['status'].nil?

    fields
  end

  def bulk_add_labels(conversation)
    return unless @params[:labels]&.[](:add)

    conversation.add_labels(@params[:labels][:add])
    conversation.save!
  end

  def bulk_snoozed_until(conversation)
    conversation.snoozed_until = parse_date_time(@params[:snoozed_until].to_s) if @params[:snoozed_until]
  end

  def remove_labels(conversation)
    return unless @params[:labels] && @params[:labels][:remove]

    labels = conversation.label_list - @params[:labels][:remove]
    conversation.update(label_list: labels)
  end

  def records_to_updated(ids)
    current_model = @params[:type].camelcase
    return unless MODEL_TYPE.include?(current_model)

    scope = current_model.constantize.where(account_id: @account.id, display_id: ids)
    Conversations::PermissionFilterService.new(scope, @user, @account).perform
  end
end
