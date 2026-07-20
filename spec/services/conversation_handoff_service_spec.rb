require 'rails_helper'

RSpec.describe ConversationHandoffService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:service) { described_class.new(conversation) }

  describe '#process_handoff' do
    context 'when handoff cooldown has not passed' do
      before do
        conversation.update!(last_handoff_at: 1.hour.ago)
      end

      it 'does not send notification' do
        expect do
          service.process_handoff(nil, 'external_escalation')
        end.not_to have_enqueued_job(EscalationNotificationJob)
      end
    end

    context 'when handoff cooldown has passed' do
      before do
        conversation.update!(last_handoff_at: 5.hours.ago)
      end

      context 'with external_escalation reason' do
        context 'when escalation_emails are configured' do
          before do
            allow(account).to receive(:escalation_emails).and_return(['escalate@example.com'])
          end

          it 'enqueues EscalationNotificationJob' do
            expect do
              service.process_handoff({ name: 'John' }, 'external_escalation', 'Help!')
            end.to have_enqueued_job(EscalationNotificationJob)
              .with(conversation.id, ['escalate@example.com'], { name: 'John' }, 'Help!')
          end
        end

        context 'when escalation_emails are not configured' do
          before do
            allow(account).to receive(:escalation_emails).and_return(nil)
          end

          it 'logs a warning and does not enqueue' do
            expect(Rails.logger).to receive(:warn).with(/Escalation email not configured/)
            expect do
              service.process_handoff(nil, 'external_escalation')
            end.not_to have_enqueued_job(EscalationNotificationJob)
          end
        end

        it 'adds escalation label to conversation' do
          conversation.update!(last_handoff_at: 5.hours.ago)
          service.process_handoff(nil, 'external_escalation')
          expect(conversation.reload.label_list).to include('escalation')
        end
      end

      context 'with vehicle_parts reason' do
        context 'when vehicle_parts_emails are configured' do
          before do
            allow(account).to receive(:vehicle_parts_emails).and_return(['parts@example.com'])
          end

          it 'enqueues SendHandoffNotificationsJob' do
            expect do
              service.process_handoff({ name: 'John' }, 'vehicle_parts')
            end.to have_enqueued_job(ConversationHandoff::SendHandoffNotificationsJob)
          end
        end

        context 'when vehicle_parts_emails are not configured' do
          before do
            allow(account).to receive(:vehicle_parts_emails).and_return(nil)
          end

          it 'logs a warning and does not enqueue' do
            expect(Rails.logger).to receive(:warn).with(/Vehicle parts email not configured/)
            expect do
              service.process_handoff(nil, 'vehicle_parts')
            end.not_to have_enqueued_job(ConversationHandoff::SendHandoffNotificationsJob)
          end
        end

        it 'adds handoff label to conversation' do
          conversation.update!(last_handoff_at: 5.hours.ago)
          service.process_handoff(nil, 'vehicle_parts')
          expect(conversation.reload.label_list).to include('handoff')
        end
      end
    end

    context 'when last_handoff_at is nil' do
      it 'allows handoff regardless of cooldown' do
        conversation.update!(last_handoff_at: nil)
        allow(account).to receive(:escalation_emails).and_return(['escalate@example.com'])

        expect do
          service.process_handoff(nil, 'external_escalation')
        end.to have_enqueued_job(EscalationNotificationJob)
      end
    end

    it 'schedules label change job after cooldown period' do
      conversation.update!(last_handoff_at: 5.hours.ago)
      allow(account).to receive(:escalation_emails).and_return(['escalate@example.com'])

      expect do
        service.process_handoff(nil, 'external_escalation')
      end.to have_enqueued_job(ScheduleHandoffLabelChangeJob)
    end

    it 'updates handoff state timestamps' do
      conversation.update!(last_handoff_at: 5.hours.ago)
      allow(account).to receive(:escalation_emails).and_return(['escalate@example.com'])

      freeze_time do
        service.process_handoff(nil, 'external_escalation')
        conversation.reload
        expect(conversation.last_handoff_at).to eq(Time.current)
        expect(conversation.handoff_attended_at).to be_nil
        expect(conversation.handoff_attended_by_id).to be_nil
      end
    end
  end
end
