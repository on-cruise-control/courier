class AccountGotoConfigurationPolicy < ApplicationPolicy
  def show?
    @account_user.administrator?
  end

  alias authorization? show?
  alias lines? show?
  alias update? show?
  alias destroy? show?
end
