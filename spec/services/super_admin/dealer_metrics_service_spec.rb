require 'rails_helper'

describe SuperAdmin::DealerMetricsService do
  let(:account) { double('Account', id: 1, dealership_id: 'dealer_1', name: 'Dealer One', active?: true) }
  let(:accounts) { [account] }
  let(:service) do
    described_class.new(
      dealership_id: nil,
      account_id: nil,
      user_id: nil,
      range_key: 'last_7_days',
      since: 7.days.ago,
      until_time: Time.current
    ).tap { |s| s.instance_variable_set(:@accounts, accounts) }
  end

  describe '#perform' do
    it 'returns initial payload with filters and sections' do
      result = service.perform
      expect(result).to include(:filters, :sections)
      expect(result[:filters]).to be_a(Hash)
      expect(result[:sections]).to be_an(Array)
    end

    it 'returns section payload when a section is specified' do
      result = service.perform(section: 'conversations')
      expect(result).to include(:key, :title, :cards)
      expect(result[:key]).to eq('conversations')
    end
  end
end
