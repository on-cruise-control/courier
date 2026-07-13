require 'rails_helper'

describe Bookings::BookingService do
  let(:dealership_id) { 'dealer_123' }
  let(:service) { described_class.new(dealership_id) }
  let(:base_uri) { 'https://api.example.com' }
  let(:api_key) { 'test_api_key' }

  before do
    allow(GlobalConfig).to receive(:get).with('DEALERSHIP_API_BASE_URL').and_return({ 'DEALERSHIP_API_BASE_URL' => base_uri })
    allow(GlobalConfig).to receive(:get).with('DEALERSHIP_API_KEY').and_return({ 'DEALERSHIP_API_KEY' => api_key })
  end

  describe '#fetch_bookings' do
    context 'when dealership_id is blank' do
      let(:service) { described_class.new('') }

      it 'returns empty result set' do
        expect(service.fetch_bookings).to eq({ results: [], count: 0 })
      end
    end

    context 'when API returns a successful response' do
      let(:response_body) { { 'data' => { 'results' => [{ 'id' => 1, 'status' => 'confirmed' }], 'count' => 1 } } }
      let(:mock_response) { instance_double(HTTParty::Response, code: 200, parsed_response: response_body) }

      before do
        allow_any_instance_of(Bookings::BookingService).to receive(:make_index_request).and_return(mock_response)
      end

      it 'parses and returns the results and count' do
        result = service.fetch_bookings(page: 1, page_size: 10)
        expect(result[:results]).to eq([{ 'id' => 1, 'status' => 'confirmed' }])
        expect(result[:count]).to eq(1)
      end
    end

    context 'when API returns an error response' do
      let(:mock_response) do
        instance_double(HTTParty::Response, code: 401, parsed_response: {})
      end

      before do
        allow_any_instance_of(Bookings::BookingService).to receive(:make_index_request).and_return(mock_response)
      end

      it 'logs the error and returns empty result set with error message' do
        result = service.fetch_bookings
        expect(result[:results]).to eq([])
        expect(result[:count]).to eq(0)
        expect(result[:error]).to be_present
      end
    end
  end

  describe '#find_booking' do
    let(:booking_id) { 42 }
    let(:response_body) { { 'data' => { 'results' => [{ 'id' => booking_id, 'status' => 'confirmed' }] } } }
    let(:mock_response) { instance_double(HTTParty::Response, code: 200, parsed_response: response_body) }

    before do
      allow_any_instance_of(Bookings::BookingService).to receive(:make_index_request).and_return(mock_response)
    end

    it 'returns the booking record when found' do
      result = service.find_booking(booking_id)
      expect(result).to eq({ 'id' => booking_id, 'status' => 'confirmed' })
    end

    it 'searches a wider range when not found initially' do
      # first call returns empty, second returns the record
      first_body = { 'data' => { 'results' => [] } }
      first_response = instance_double(HTTParty::Response, code: 200, parsed_response: first_body)
      allow_any_instance_of(Bookings::BookingService).to receive(:make_index_request).and_return(first_response, mock_response)

      result = service.find_booking(booking_id)
      expect(result).to eq({ 'id' => booking_id, 'status' => 'confirmed' })
    end

    context 'when booking_id is missing' do
      it 'returns an error hash' do
        result = service.find_booking(nil)
        expect(result).to eq({ error: 'Booking ID is required' })
      end
    end
  end
end
