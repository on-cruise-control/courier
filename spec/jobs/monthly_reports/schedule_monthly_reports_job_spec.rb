require 'rails_helper'

RSpec.describe MonthlyReports::ScheduleMonthlyReportsJob do
  let(:account) { create(:account) }

  describe '#perform' do
    before do
      Account.destroy_all
    end

    context 'when no accounts with inboxes exist' do
      it 'does not enqueue any send jobs' do
        expect(MonthlyReports::SendMonthlyReportJob).not_to receive(:perform_later)
        described_class.perform_now
      end
    end

    context 'when accounts with inboxes exist' do
      it 'enqueues a send job for each account' do
        inbox = create(:inbox, account: account)
        account.inboxes << inbox

        expect(MonthlyReports::SendMonthlyReportJob).to receive(:perform_later)
          .with(account.id, kind_of(Date), kind_of(Date))

        described_class.perform_now
      end
    end
  end
end
