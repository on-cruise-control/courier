require 'rails_helper'

RSpec.describe Users::ConfirmationReminderJob, type: :job do
  let(:account) { create(:account) }
  let(:user) { create(:user, skip_confirmation: false, account: account) }
  let(:mailer_double) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

  before do
    allow(AgentNotifications::ConfirmationReminderMailer).to receive(:reminder).and_return(mailer_double)
  end

  describe '#perform' do
    context 'when the user no longer exists' do
      it 'does not send a reminder email' do
        described_class.perform_now(-1, 'first')

        expect(AgentNotifications::ConfirmationReminderMailer).not_to have_received(:reminder)
      end
    end

    context 'when the user is already confirmed' do
      before { user.confirm }

      it 'does not send a reminder email' do
        described_class.perform_now(user.id, 'first')

        expect(AgentNotifications::ConfirmationReminderMailer).not_to have_received(:reminder)
      end

      it 'does not schedule the second reminder' do
        expect { described_class.perform_now(user.id, 'first') }.not_to have_enqueued_job(described_class)
      end
    end

    context 'when the user is still unconfirmed and stage is first' do
      it 'sends the first reminder email' do
        described_class.perform_now(user.id, 'first')

        expect(AgentNotifications::ConfirmationReminderMailer).to have_received(:reminder).with(user: user, stage: 'first')
        expect(mailer_double).to have_received(:deliver_now)
      end

      it 'schedules the second reminder' do
        expect { described_class.perform_now(user.id, 'first') }
          .to have_enqueued_job(described_class).with(user.id, 'second')
      end
    end

    context 'when the user is still unconfirmed and stage is second' do
      it 'sends the second reminder email' do
        described_class.perform_now(user.id, 'second')

        expect(AgentNotifications::ConfirmationReminderMailer).to have_received(:reminder).with(user: user, stage: 'second')
        expect(mailer_double).to have_received(:deliver_now)
      end

      it 'does not schedule another reminder' do
        expect { described_class.perform_now(user.id, 'second') }.not_to have_enqueued_job(described_class)
      end
    end
  end
end
