# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentNotifications::ConfirmationReminderMailer do
  let(:account) { create(:account) }
  let(:inviter) { create(:user, account: account) }
  let(:user) { create(:user, name: 'Jamie Agent', skip_confirmation: false, account: account, inviter: inviter) }

  describe '#reminder' do
    context 'when stage is first' do
      let(:mail) { described_class.reminder(user: user, stage: 'first').deliver_now }

      it 'renders the subject' do
        expect(mail.subject).to eq('Reminder: Finish setting up your account')
      end

      it 'renders the receiver email' do
        expect(mail.to).to eq([user.email])
      end

      it 'greets the recipient by name' do
        expect(mail.body.encoded).to include('Jamie Agent')
      end

      it 'mentions the invited workspace' do
        expect(mail.body.encoded).to include("invited to join the #{account.name} workspace")
      end

      it 'tells the agent to log in from their mobile device' do
        expect(mail.body.encoded).to include('log in from your mobile device')
        expect(mail.body.encoded).to include('sales bookings and escalations')
      end

      it 'links to the password setup page with a reset token' do
        expect(mail.body.encoded).to include('app/auth/password/edit')
        expect(mail.body.encoded).to match(/reset_password_token=\S+/)
      end

      it 'renders the first-stage heading' do
        expect(mail.body.encoded).to include('Complete your account setup')
      end
    end

    context 'when stage is second' do
      let(:mail) { described_class.reminder(user: user, stage: 'second').deliver_now }

      it 'renders the second-stage subject' do
        expect(mail.subject).to eq('Reminder: Your account is still waiting for you')
      end

      it 'renders the second-stage heading' do
        expect(mail.body.encoded).to include('account is still waiting')
      end
    end

    context 'when the user has no inviter/account' do
      let(:standalone_user) { create(:user, name: 'Solo Agent', skip_confirmation: false) }
      let(:mail) { described_class.reminder(user: standalone_user, stage: 'first').deliver_now }

      it 'falls back to generic copy without a workspace name' do
        expect(mail.body.encoded).to include('finished setting it up yet')
        expect(mail.body.encoded).not_to include('workspace')
      end
    end
  end
end
