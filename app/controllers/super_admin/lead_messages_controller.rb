class SuperAdmin::LeadMessagesController < SuperAdmin::ApplicationController
  def show
    @message = Facebook::LeadAds::Message.template
  end

  def update
    previous_name = Facebook::LeadAds::Message.whatsapp_template_name
    Facebook::LeadAds::Message.update(params.require(:message))
    changed = previous_name != Facebook::LeadAds::Message.whatsapp_template_name
    Facebook::LeadAds::SubmitMessageTemplatesJob.perform_later(*(previous_name if changed))
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_to super_admin_lead_message_path, notice: 'Lead message saved and sent to WhatsApp for review'
    # rubocop:enable Rails/I18nLocaleTexts
  end
end
