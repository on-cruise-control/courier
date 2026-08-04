require 'rails_helper'

RSpec.describe Internal::TriggerDailyScheduledItemsJob do
  subject(:perform_job) { described_class.perform_now }

  let(:configured_job) { instance_double(ActiveJob::ConfiguredJob, perform_later: true) }

  before do
    allow(Internal::CheckNewVersionsJob).to receive(:set).and_return(configured_job)
  end

  it 'enqueues the job' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
      .on_queue('scheduled_jobs')
  end

  it 'does not schedule the version check outside production' do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))

    perform_job

    expect(Internal::CheckNewVersionsJob).not_to have_received(:set)
  end
end
