require 'rails_helper'

RSpec.describe FilterService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:params) { ActionController::Parameters.new(payload: []) }
  let(:service) { described_class.new(params, user) }

  describe '#filter_operation' do
    context 'with equal_to operator' do
      it 'builds correct filter string' do
        result = service.filter_operation(
          { 'attribute_key' => 'status', 'filter_operator' => 'equal_to', 'values' => ['open'] }.with_indifferent_access,
          0
        )
        expect(result).to eq('IN (:value_0)')
      end
    end

    context 'with contains operator' do
      it 'builds correct filter string' do
        result = service.filter_operation(
          { 'attribute_key' => 'content', 'filter_operator' => 'contains', 'values' => ['hello'] }.with_indifferent_access,
          0
        )
        expect(result).to eq('ILIKE ANY (ARRAY[:value_0])')
      end
    end

    context 'with is_present operator' do
      it 'sets filter value to IS NOT NULL' do
        result = service.filter_operation(
          { 'attribute_key' => 'assignee', 'filter_operator' => 'is_present' }.with_indifferent_access,
          0
        )
        expect(result).to eq('IS NOT NULL')
        expect(service.instance_variable_get(:@filter_values)['value_0']).to eq('IS NOT NULL')
      end
    end

    context 'with is_not_present operator' do
      it 'sets filter value to IS NULL' do
        result = service.filter_operation(
          { 'attribute_key' => 'assignee', 'filter_operator' => 'is_not_present' }.with_indifferent_access,
          0
        )
        expect(result).to eq('IS NULL')
        expect(service.instance_variable_get(:@filter_values)['value_0']).to eq('IS NULL')
      end
    end
  end

  describe '#filter_values' do
    context 'when attribute_key is status' do
      it 'returns conversation status values' do
        result = service.filter_values(
          { 'attribute_key' => 'status', 'values' => ['open'] }
        )
        expect(result).to be_an(Array)
      end
    end

    context 'when attribute_key is priority' do
      it 'returns conversation priority values' do
        result = service.filter_values(
          { 'attribute_key' => 'priority', 'values' => ['high'] }
        )
        expect(result).to be_an(Array)
      end
    end

    context 'when attribute_key is content' do
      it 'returns downcased values' do
        result = service.filter_values(
          { 'attribute_key' => 'content', 'values' => ['HELLO'] }
        )
        expect(result).to eq(['hello'])
      end
    end
  end

  describe '#normalize_params' do
    context 'with indifferent access params' do
      let(:params) do
        ActionController::Parameters.new(
          payload: [
            { attribute_key: 'status', filter_operator: 'equal_to', values: ['open'] }
          ]
        )
      end

      it 'normalizes params with indifferent access' do
        normalized = service.send(:normalize_params, params)
        expect(normalized).to have_key(:payload)
        expect(normalized[:payload]).to be_an(Array)
      end
    end

    context 'with non-indifferent params' do
      let(:params) { { 'payload' => ['test'] } }

      it 'returns params as-is' do
        normalized = service.send(:normalize_params, params)
        expect(normalized).to eq(params)
      end
    end
  end
end
