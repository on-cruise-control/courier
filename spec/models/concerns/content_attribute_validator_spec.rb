require 'rails_helper'

RSpec.describe ContentAttributeValidator, type: :validator do
  # Create a simple test model for validation
  before_all do
    # rubocop:disable Lint/ConstantDefinitionInBlock
    # rubocop:disable RSpec/LeakyConstantDeclaration
    TestModelForContentAttributeValidation = Struct.new(:content_type, :items, :content_attributes) do
      include ActiveModel::Validations

      validates_with ContentAttributeValidator
    end
    # rubocop:enable Lint/ConstantDefinitionInBlock
    # rubocop:enable RSpec/LeakyConstantDeclaration
  end

  describe 'input_select' do
    let(:model) { TestModelForContentAttributeValidation.new('input_select', items, {}) }

    context 'with valid items' do
      let(:items) { [{ title: 'Option 1', value: 'opt1' }, { title: 'Option 2', value: 'opt2' }] }

      it 'passes validation' do
        expect(model.valid?).to be true
      end
    end

    context 'with blank items' do
      let(:items) { [] }

      it 'fails validation' do
        expect(model.valid?).to be false
        expect(model.errors[:content_attributes]).to include('At least one item is required.')
      end
    end

    context 'with invalid keys' do
      let(:items) { [{ title: 'Option 1', invalid_key: 'value' }] }

      it 'fails validation' do
        expect(model.valid?).to be false
        expect(model.errors[:content_attributes]).to include(a_string_matching('contains invalid keys'))
      end
    end
  end

  describe 'cards' do
    let(:model) { TestModelForContentAttributeValidation.new('cards', items, {}) }

    context 'with valid items including actions' do
      let(:items) do
        [{ title: 'Card 1', description: 'Desc', actions: [{ text: 'Click', type: 'link', payload: {}, uri: 'http://example.com' }] }]
      end

      it 'passes validation' do
        expect(model.valid?).to be true
      end
    end

    context 'with items missing actions' do
      let(:items) { [{ title: 'Card 1', description: 'Desc' }] }

      it 'fails validation' do
        expect(model.valid?).to be false
        expect(model.errors[:content_attributes]).to include(a_string_matching('missing actions'))
      end
    end
  end

  describe 'form' do
    let(:model) { TestModelForContentAttributeValidation.new('form', items, {}) }

    context 'with valid form items' do
      let(:items) { [{ type: 'text', placeholder: 'Enter name', label: 'Name', name: 'name', required: true }] }

      it 'passes validation' do
        expect(model.valid?).to be true
      end
    end

    context 'with invalid keys' do
      let(:items) { [{ type: 'text', invalid_key: 'value' }] }

      it 'fails validation' do
        expect(model.valid?).to be false
        expect(model.errors[:content_attributes]).to include(a_string_matching('contains invalid keys'))
      end
    end
  end

  describe 'article' do
    let(:model) { TestModelForContentAttributeValidation.new('article', items, {}) }

    context 'with valid article items' do
      let(:items) { [{ title: 'Article 1', description: 'Desc', link: 'http://example.com' }] }

      it 'passes validation' do
        expect(model.valid?).to be true
      end
    end
  end
end
