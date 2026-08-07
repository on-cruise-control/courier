# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentNotifications::OnboardingInstructionsMailer do
  let(:account) { create(:account, name: 'Riverside Motors') }
  let(:inviter) { create(:user, account: account) }
  let(:user) { create(:user, name: 'Jamie Agent', skip_confirmation: false, account: account, inviter: inviter) }

  describe '#instructions' do
    let(:mail) { described_class.instructions(user: user).deliver_now }

    it 'renders the subject with the account name' do
      expect(mail.subject).to eq('Welcome to Riverside Motors — what to expect as an agent')
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([user.email])
    end

    it 'greets the recipient by name' do
      expect(mail.body.encoded).to include('Jamie Agent')
    end

    it 'welcomes the agent to the account' do
      expect(mail.body.encoded).to include('Welcome to Riverside Motors!')
    end

    it 'explains handoffs' do
      expect(mail.body.encoded).to include('Handoffs:')
    end

    it 'explains escalations' do
      expect(mail.body.encoded).to include('Escalations:')
    end

    it 'explains appointment bookings' do
      expect(mail.body.encoded).to include('Appointment Bookings:')
    end

    it 'explains negative comments' do
      expect(mail.body.encoded).to include('Negative Comments:')
    end
  end
end
