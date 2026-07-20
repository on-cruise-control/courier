require 'rails_helper'

RSpec.describe CsatTemplateNameService do
  describe '.csat_template_name' do
    context 'without version' do
      it 'returns base template name' do
        result = described_class.csat_template_name(123)
        expect(result).to eq('customer_satisfaction_survey_123')
      end
    end

    context 'with version' do
      it 'returns versioned template name' do
        result = described_class.csat_template_name(123, 2)
        expect(result).to eq('customer_satisfaction_survey_123_2')
      end
    end
  end

  describe '.extract_version' do
    context 'with versioned template name' do
      it 'extracts version number' do
        result = described_class.extract_version('customer_satisfaction_survey_123_2', 123)
        expect(result).to eq(2)
      end
    end

    context 'with base template name' do
      it 'returns nil' do
        result = described_class.extract_version('customer_satisfaction_survey_123', 123)
        expect(result).to be_nil
      end
    end

    context 'with blank template name' do
      it 'returns nil' do
        result = described_class.extract_version(nil, 123)
        expect(result).to be_nil
      end
    end
  end

  describe '.generate_next_template_name' do
    context 'with current versioned template' do
      it 'generates next version' do
        result = described_class.generate_next_template_name(
          'customer_satisfaction_survey_123',
          123,
          'customer_satisfaction_survey_123_2'
        )
        expect(result).to eq('customer_satisfaction_survey_123_3')
      end
    end

    context 'with current base template' do
      it 'generates version 1' do
        result = described_class.generate_next_template_name(
          'customer_satisfaction_survey_123',
          123,
          'customer_satisfaction_survey_123'
        )
        expect(result).to eq('customer_satisfaction_survey_123_1')
      end
    end

    context 'with blank current template' do
      it 'returns base name' do
        result = described_class.generate_next_template_name(
          'customer_satisfaction_survey_123',
          123,
          nil
        )
        expect(result).to eq('customer_satisfaction_survey_123')
      end
    end
  end

  describe '.matches_csat_pattern?' do
    context 'with matching base pattern' do
      it 'returns true' do
        result = described_class.matches_csat_pattern?('customer_satisfaction_survey_123', 123)
        expect(result).to be true
      end
    end

    context 'with matching versioned pattern' do
      it 'returns true' do
        result = described_class.matches_csat_pattern?('customer_satisfaction_survey_123_2', 123)
        expect(result).to be true
      end
    end

    context 'with non-matching template name' do
      it 'returns false' do
        result = described_class.matches_csat_pattern?('other_template', 123)
        expect(result).to be false
      end
    end

    context 'with blank template name' do
      it 'returns false' do
        result = described_class.matches_csat_pattern?(nil, 123)
        expect(result).to be false
      end
    end
  end
end
