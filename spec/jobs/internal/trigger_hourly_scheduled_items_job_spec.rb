require 'rails_helper'

RSpec.describe Internal::TriggerHourlyScheduledItemsJob do
  subject(:perform_job) { described_class.perform_now }

  it 'enqueues the job' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
      .on_queue('scheduled_jobs')
  end

  it 'does not raise error when performed' do
    expect { perform_job }.not_to raise_error
  end
end
