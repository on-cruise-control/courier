require 'rails_helper'

RSpec.describe MonthlyReports::SendMonthlyReportJob do
  let(:account) { create(:account) }
  let(:start_date) { 30.days.ago.to_date }
  let(:end_date) { Date.today }

  describe '#perform' do
    context 'when account is not found' do
      it 'returns without action' do
        expect do
          described_class.perform_now(nil, start_date, end_date)
        end.not_to raise_error
      end
    end

    context 'when account is present' do
      it 'generates metrics and sends notification' do
        metrics_service = instance_double(MonthlyReports::GenerateMetricsService)
        metrics = {
          new_conversations: 10,
          total_messages: 50,
          booking_forms_completed: 5,
          handoff_forms_completed: 3,
          handoff_attended_count: 2,
          conversion_rate: 40.0,
          estimated_value: 5000,
          conversations_by_channel: { 'Website' => 8, 'Facebook' => 2 }
        }

        expect(MonthlyReports::GenerateMetricsService).to receive(:new)
          .with(account, start_date, end_date)
          .and_return(metrics_service)
        expect(metrics_service).to receive(:perform).and_return(metrics)

        # Stub chart generation to return nil so it falls through to SlackNotifierService
        expect(Reports::MonthlyPieChart).to receive(:generate).and_return(nil)

        expect(SlackNotifierService).to receive(:call).with(
          hash_including(text: /Cruise Control Monthly Impact Report/, is_impact_report: true)
        )

        described_class.perform_now(account.id, start_date, end_date)
      end
    end
  end
end
