require 'rails_helper'

RSpec.describe Users::ConfirmationReminderJob, type: :job do
  let(:account) { create(:account) }
  let(:user) { create(:user, skip_confirmation: false, account: account) }

  describe '#perform' do
    context 'when the user no longer exists' do
      it 'does not send a reminder email' do
        expect { described_class.perform_now(-1, 'first') }.not_to(change { ActionMailer::Base.deliveries.count })
      end
    end

    context 'when the user is already confirmed' do
      before { user.confirm }

      it 'does not send a reminder email' do
        expect { described_class.perform_now(user.id, 'first') }.not_to(change { ActionMailer::Base.deliveries.count })
      end

      it 'does not schedule the second reminder' do
        expect { described_class.perform_now(user.id, 'first') }.not_to have_enqueued_job(described_class)
      end
    end

    context 'when the user is still unconfirmed and stage is first' do
      it 'sends the first reminder email' do
        expect { described_class.perform_now(user.id, 'first') }
          .to change { ActionMailer::Base.deliveries.count }.by(1)

        mail = ActionMailer::Base.deliveries.last
        expect(mail.to).to eq([user.email])
        expect(mail.subject).to eq('Reminder: Finish setting up your account')
      end

      it 'schedules the second reminder' do
        expect { described_class.perform_now(user.id, 'first') }
          .to have_enqueued_job(described_class).with(user.id, 'second')
      end
    end

    context 'when the user is still unconfirmed and stage is second' do
      it 'sends the second reminder email' do
        expect { described_class.perform_now(user.id, 'second') }
          .to change { ActionMailer::Base.deliveries.count }.by(1)

        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq('Reminder: Your account is still waiting for you')
      end

      it 'does not schedule another reminder' do
        expect { described_class.perform_now(user.id, 'second') }.not_to have_enqueued_job(described_class)
      end
    end
  end
end
