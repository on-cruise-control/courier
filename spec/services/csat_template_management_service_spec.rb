require 'rails_helper'

RSpec.describe CsatTemplateManagementService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:service) { described_class.new(inbox) }

  describe '#template_status' do
    context 'when csat_config has no template' do
      before do
        allow(inbox).to receive(:csat_config).and_return(nil)
      end

      it 'returns template_exists: false' do
        result = service.template_status
        expect(result).to eq({ template_exists: false })
      end
    end

    context 'when csat_config has template' do
      context 'for twilio whatsapp' do
        before do
          allow(inbox).to receive(:twilio_whatsapp?).and_return(true)
          allow(inbox).to receive(:csat_config).and_return({ 'template' => { 'content_sid' => '123' } })
        end

        it 'calls get_twilio_template_status' do
          expect_any_instance_of(Twilio::CsatTemplateService).to receive(:get_template_status).and_return(
            success: true, template: { status: 'approved' }
          )
          result = service.template_status
          expect(result[:template_exists]).to be true
        end
      end

      context 'for whatsapp cloud' do
        before do
          allow(inbox).to receive(:twilio_whatsapp?).and_return(false)
          allow(inbox).to receive(:csat_config).and_return({ 'template' => { 'name' => 'test_template' } })
        end

        it 'calls get_whatsapp_template_status' do
          expect_any_instance_of(Whatsapp::CsatTemplateService).to receive(:get_template_status).and_return(
            success: true, template: { status: 'approved', id: '123' }
          )
          result = service.template_status
          expect(result[:template_exists]).to be true
        end
      end
    end
  end

  describe '#create_template' do
    context 'with valid template params' do
      let(:template_params) { { message: 'Rate us' } }

      context 'for twilio whatsapp' do
        before do
          allow(inbox).to receive(:twilio_whatsapp?).and_return(true)
          allow(inbox).to receive(:csat_config).and_return({})
          allow(inbox).to receive(:update!).and_return(true)
        end

        it 'creates template and updates csat_config' do
          expect_any_instance_of(Twilio::CsatTemplateService).to receive(:create_template).and_return(
            success: true, content_sid: '123', status: 'pending'
          )
          result = service.create_template(template_params)
          expect(result[:success]).to be true
        end
      end

      context 'for whatsapp cloud' do
        before do
          allow(inbox).to receive(:twilio_whatsapp?).and_return(false)
          allow(inbox).to receive(:csat_config).and_return({})
          allow(inbox).to receive(:update!).and_return(true)
        end

        it 'creates template and updates csat_config' do
          expect_any_instance_of(Whatsapp::CsatTemplateService).to receive(:create_template).and_return(
            success: true, template_id: '456', template_name: 'test'
          )
          result = service.create_template(template_params)
          expect(result[:success]).to be true
        end
      end
    end

    context 'with missing message' do
      let(:template_params) { {} }

      it 'returns failure hash' do
        result = service.create_template(template_params)
        expect(result).to eq({ success: false, service_error: 'Template creation failed' })
      end
    end
  end
end
