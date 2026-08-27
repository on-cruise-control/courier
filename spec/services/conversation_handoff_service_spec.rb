require 'rails_helper'

RSpec.describe ConversationHandoffService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:service) { described_class.new(conversation) }

  area_escalation_cases = {
    'sales_escalation' => {
      field: :sales_escalation_emails, job: 'SalesEscalationNotificationJob', label: 'sales_escalation', color: '#F97316'
    },
    'service_escalation' => {
      field: :service_escalation_emails, job: 'ServiceEscalationNotificationJob', label: 'service_escalation', color: '#A855F7'
    },
    'vehicle_parts_escalation' => {
      field: :vehicle_parts_escalation_emails, job: 'VehiclePartsEscalationNotificationJob',
      label: 'vehicle_parts_escalation', color: '#0D9488'
    }
  }

  describe '#process_handoff' do
    context 'when handoff cooldown has not passed' do
      before { conversation.update!(last_handoff_at: 1.hour.ago) }

      it 'does not send a notification' do
        expect do
          service.process_handoff(nil, 'sales_escalation')
        end.not_to have_enqueued_job(SalesEscalationNotificationJob)
      end
    end

    context 'when the handoff reason is not recognised' do
      before { conversation.update!(last_handoff_at: 5.hours.ago) }

      it 'does nothing for internal_escalation (handled on the Stark side)' do
        expect do
          service.process_handoff(nil, 'internal_escalation')
        end.not_to have_enqueued_job
        expect(conversation.reload.label_list).not_to include('escalation')
      end

      it 'does nothing for the removed external_escalation reason' do
        expect do
          service.process_handoff(nil, 'external_escalation')
        end.not_to have_enqueued_job
      end
    end

    area_escalation_cases.each do |reason, config|
      context "with the #{reason} reason (cooldown passed)" do
        let(:job_class) { config[:job].constantize }

        before { conversation.update!(last_handoff_at: 5.hours.ago) }

        context "when #{config[:field]} are configured" do
          before { allow(account).to receive(config[:field]).and_return(['area@example.com']) }

          it "enqueues #{config[:job]} with the area emails" do
            expect do
              service.process_handoff({ name: 'John' }, reason, 'Help!')
            end.to have_enqueued_job(job_class).with(conversation.id, ['area@example.com'], { name: 'John' }, 'Help!')
          end

          it 'adds the department escalation label and schedules the label change' do
            expect do
              service.process_handoff(nil, reason)
            end.to have_enqueued_job(ScheduleHandoffLabelChangeJob)
            expect(conversation.reload.label_list).to include(config[:label])
            expect(conversation.label_list).not_to include('escalation')
          end

          it 'creates the department label with its own colour on the sidebar' do
            service.process_handoff(nil, reason)
            label = account.labels.find_by(title: config[:label])
            expect(label).to have_attributes(color: config[:color], show_on_sidebar: true)
          end
        end

        context "when #{config[:field]} are not configured" do
          before { allow(account).to receive(config[:field]).and_return([]) }

          it 'logs a warning and does not enqueue the job' do
            expect(Rails.logger).to receive(:warn).with(/#{reason} email not configured/)
            expect do
              service.process_handoff(nil, reason)
            end.not_to have_enqueued_job(job_class)
          end
        end
      end
    end

    context 'with the vehicle_parts reason (cooldown passed)' do
      before { conversation.update!(last_handoff_at: 5.hours.ago) }

      it 'enqueues SendHandoffNotificationsJob when vehicle_parts_emails are configured' do
        allow(account).to receive(:vehicle_parts_emails).and_return(['parts@example.com'])
        expect do
          service.process_handoff({ name: 'John' }, 'vehicle_parts')
        end.to have_enqueued_job(ConversationHandoff::SendHandoffNotificationsJob)
      end

      it 'adds the handoff label to the conversation' do
        service.process_handoff(nil, 'vehicle_parts')
        expect(conversation.reload.label_list).to include('handoff')
      end
    end

    context 'when last_handoff_at is nil' do
      it 'allows the handoff regardless of cooldown' do
        conversation.update!(last_handoff_at: nil)
        allow(account).to receive(:sales_escalation_emails).and_return(['escalate@example.com'])

        expect do
          service.process_handoff(nil, 'sales_escalation')
        end.to have_enqueued_job(SalesEscalationNotificationJob)
      end
    end

    it 'updates the handoff state timestamps' do
      conversation.update!(last_handoff_at: 5.hours.ago)
      allow(account).to receive(:sales_escalation_emails).and_return(['escalate@example.com'])

      freeze_time do
        service.process_handoff(nil, 'sales_escalation')
        conversation.reload
        expect(conversation.last_handoff_at).to eq(Time.current)
        expect(conversation.handoff_attended_by_id).to be_nil
      end
    end
  end
end
