require 'rails_helper'

RSpec.describe Internal::SeedAccountJob do
  let(:account) { create(:account) }

  describe '#perform' do
    it 'calls the AccountSeeder with the account' do
      seeder = instance_double(Seeders::AccountSeeder)
      expect(Seeders::AccountSeeder).to receive(:new).with(account: account).and_return(seeder)
      expect(seeder).to receive(:perform!)
      described_class.perform_now(account)
    end
  end
end
