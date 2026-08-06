require 'rails_helper'

describe Offers::OfferService do
  let(:dealership_id) { 'dealer_123' }
  let(:service) { described_class.new(dealership_id) }
  let(:base_uri) { 'https://api.example.com' }
  let(:api_key) { 'test_api_key' }

  before do
    allow(GlobalConfig).to receive(:get).with('DEALERSHIP_API_BASE_URL').and_return({ 'DEALERSHIP_API_BASE_URL' => base_uri })
    allow(GlobalConfig).to receive(:get).with('DEALERSHIP_API_KEY').and_return({ 'DEALERSHIP_API_KEY' => api_key })
  end

  describe '#fetch_offers' do
    context 'when dealership_id is blank' do
      let(:service) { described_class.new('') }

      it 'returns empty results without calling the API' do
        expect(described_class).not_to receive(:get)
        expect(service.fetch_offers).to eq({ results: [] })
      end
    end

    context 'when the API returns a successful response' do
      let(:response_body) { { 'body' => { 'data' => [{ 'id' => 1, 'title' => 'Summer Sale' }] } } }
      let(:mock_response) { instance_double(HTTParty::Response, code: 200, parsed_response: response_body) }

      before do
        allow(described_class).to receive(:get).and_return(mock_response)
      end

      it 'returns the list of offers' do
        result = service.fetch_offers
        expect(result).to eq({ results: [{ 'id' => 1, 'title' => 'Summer Sale' }] })
      end
    end

    context 'when the API returns an error response' do
      let(:mock_response) { instance_double(HTTParty::Response, code: 401, parsed_response: {}) }

      before do
        allow(described_class).to receive(:get).and_return(mock_response)
      end

      it 'returns an empty result set with the error message and status' do
        result = service.fetch_offers
        expect(result[:results]).to eq([])
        expect(result[:error]).to be_present
        expect(result[:status]).to eq(401)
      end
    end
  end

  describe '#create_offer' do
    let(:params) { { title: 'New Offer', start_date: '2026-01-01', end_date: '2026-01-31' } }

    context 'when dealership_id is blank' do
      let(:service) { described_class.new('') }

      it 'returns an error without calling the API' do
        expect(described_class).not_to receive(:post)
        result = service.create_offer(params)
        expect(result[:error]).to be_present
        expect(result[:status]).to eq(422)
      end
    end

    context 'when the API returns a successful response' do
      let(:response_body) { { 'body' => { 'data' => { 'id' => 1, 'title' => 'New Offer' } } } }
      let(:mock_response) { instance_double(HTTParty::Response, code: 201, parsed_response: response_body) }

      before do
        allow(described_class).to receive(:post).and_return(mock_response)
      end

      it 'streams the request without the buggy httparty multipart streaming path' do
        service.create_offer(params)
        expect(described_class).to have_received(:post).with(
          anything, hash_including(stream_body: false)
        )
      end

      it 'returns the created offer' do
        result = service.create_offer(params)
        expect(result).to eq({ 'id' => 1, 'title' => 'New Offer' })
      end
    end

    context 'when the API returns a validation error' do
      let(:response_body) { { 'message' => 'Invalid data', 'error' => { 'title' => ['This field is required.'] } } }
      let(:mock_response) { instance_double(HTTParty::Response, code: 422, parsed_response: response_body) }

      before do
        allow(described_class).to receive(:post).and_return(mock_response)
      end

      it 'returns the error message and status from the API' do
        result = service.create_offer(params)
        expect(result[:error]).to eq('Invalid data')
        expect(result[:status]).to eq(422)
      end
    end

    context 'when the API raises an unexpected error' do
      before do
        allow(described_class).to receive(:post).and_raise(StandardError.new('boom'))
      end

      it 'rescues the error and returns a 500 status' do
        result = service.create_offer(params)
        expect(result[:error]).to eq('Internal Service Error')
        expect(result[:status]).to eq(500)
      end
    end
  end

  describe '#update_offer' do
    let(:params) { { title: 'Updated Offer' } }

    context 'when offer_id is blank' do
      it 'returns an error without calling the API' do
        expect(described_class).not_to receive(:put)
        result = service.update_offer(nil, params)
        expect(result[:error]).to be_present
        expect(result[:status]).to eq(422)
      end
    end

    context 'when the API returns a successful response' do
      let(:response_body) { { 'body' => { 'data' => { 'id' => 1, 'title' => 'Updated Offer' } } } }
      let(:mock_response) { instance_double(HTTParty::Response, code: 200, parsed_response: response_body) }

      before do
        allow(described_class).to receive(:put).and_return(mock_response)
      end

      it 'returns the updated offer' do
        result = service.update_offer(1, params)
        expect(result).to eq({ 'id' => 1, 'title' => 'Updated Offer' })
      end
    end

    context 'when the API returns a not found error' do
      let(:mock_response) { instance_double(HTTParty::Response, code: 404, parsed_response: {}) }

      before do
        allow(described_class).to receive(:put).and_return(mock_response)
      end

      it 'returns the error message and status' do
        result = service.update_offer(1, params)
        expect(result[:error]).to eq('Offer not found')
        expect(result[:status]).to eq(404)
      end
    end
  end

  describe '#delete_offer' do
    context 'when offer_id is blank' do
      it 'returns an error without calling the API' do
        expect(described_class).not_to receive(:delete)
        result = service.delete_offer(nil)
        expect(result[:error]).to be_present
        expect(result[:status]).to eq(422)
      end
    end

    context 'when the API returns a successful response' do
      let(:mock_response) { instance_double(HTTParty::Response, code: 200, parsed_response: {}) }

      before do
        allow(described_class).to receive(:delete).and_return(mock_response)
      end

      it 'returns success' do
        expect(service.delete_offer(1)).to eq({ success: true })
      end
    end

    context 'when the API returns a server error' do
      let(:mock_response) { instance_double(HTTParty::Response, code: 500, parsed_response: {}) }

      before do
        allow(described_class).to receive(:delete).and_return(mock_response)
      end

      it 'returns the error message and status' do
        result = service.delete_offer(1)
        expect(result[:error]).to eq('Dealership API server error')
        expect(result[:status]).to eq(500)
      end
    end
  end
end
