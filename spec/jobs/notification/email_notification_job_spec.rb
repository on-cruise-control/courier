require 'rails_helper'

RSpec.describe Notification::EmailNotificationJob do
  let(:notification) { create(:notification) }
  let(:email_service) { instance_double(Notification::EmailNotificationService) }

  describe '#perform' do
    context 'when notification is unread' do
      it 'calls Notification::EmailNotificationService with the notification' do
        allow(Notification::EmailNotificationService).to receive(:new).with(notification: notification).and_return(email_service)
        allow(email_service).to receive(:perform)

        described_class.perform_now(notification)

        expect(Notification::EmailNotificationService).to have_received(:new).with(notification: notification)
        expect(email_service).to have_received(:perform)
      end
    end

    context 'when notification has been read' do
      it 'does not call the email notification service' do
        notification.update!(read_at: Time.current)

        expect(Notification::EmailNotificationService).not_to receive(:new)

        described_class.perform_now(notification)
      end
    end
  end
end
