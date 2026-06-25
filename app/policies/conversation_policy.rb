class ConversationPolicy < ApplicationPolicy
  def index?
    true
  end

  def destroy?
    @account_user&.administrator?
  end

  def show?
    administrator? || agent_bot? || account_user.present?
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def agent_bot?
    user.is_a?(AgentBot)
  end

  def assigned_to_user?
    record.assignee_id == user.id
  end

  def participant?
    record.conversation_participants.exists?(user_id: user.id)
  end
end

ConversationPolicy.prepend_mod_with('ConversationPolicy')
