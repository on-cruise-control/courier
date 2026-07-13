require 'rails_helper'

RSpec.describe Notification::PushNotificationJob do
  let(:notification) { create(:notification) }
  let(:push_service) { instance_double(Notification::PushNotificationService) }

  describe '#perform' do
    it 'calls Notification::PushNotificationService with the notification' do
      allow(Notification::PushNotificationService).to receive(:new).with(notification: notification).and_return(push_service)
      allow(push_service).to receive(:perform)

      described_class.perform_now(notification)

      expect(Notification::PushNotificationService).to have_received(:new).with(notification: notification)
      expect(push_service).to have_received(:perform)
    end
  end
end
