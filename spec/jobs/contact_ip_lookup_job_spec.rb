require 'rails_helper'

RSpec.describe ContactIpLookupJob do
  let(:contact) { create(:contact, additional_attributes: { 'created_at_ip' => '192.168.1.1' }) }
  let(:ip_lookup_service) { instance_double(IpLookupService) }
  let(:geocoder_result) do
    double('geocoder_result', city: 'San Francisco', country: 'United States', country_code: 'US')
  end

  describe '#perform' do
    context 'when IP lookup succeeds' do
      before do
        allow(IpLookupService).to receive(:new).and_return(ip_lookup_service)
        allow(ip_lookup_service).to receive(:perform).with('192.168.1.1').and_return(geocoder_result)
      end

      it 'updates the contact with location data from the IP' do
        described_class.perform_now(contact)
        contact.reload
        expect(contact.additional_attributes['city']).to eq('San Francisco')
        expect(contact.additional_attributes['country']).to eq('United States')
        expect(contact.additional_attributes['country_code']).to eq('US')
      end
    end

    context 'when IP lookup returns nil' do
      before do
        allow(IpLookupService).to receive(:new).and_return(ip_lookup_service)
        allow(ip_lookup_service).to receive(:perform).with('192.168.1.1').and_return(nil)
      end

      it 'does not update the contact' do
        expect(contact.additional_attributes).not_to have_key('city')
        described_class.perform_now(contact)
        contact.reload
        expect(contact.additional_attributes).not_to have_key('city')
      end
    end

    context 'when contact has no IP address' do
      let(:contact_no_ip) { create(:contact, additional_attributes: {}) }

      it 'calls the IP lookup service with nil and does not update the contact' do
        allow(IpLookupService).to receive(:new).and_return(ip_lookup_service)
        allow(ip_lookup_service).to receive(:perform).with(nil).and_return(nil)

        described_class.perform_now(contact_no_ip)
        contact_no_ip.reload
        expect(contact_no_ip.additional_attributes).not_to have_key('city')
      end
    end
  end
end
