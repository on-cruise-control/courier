# Sends the lead message to WhatsApp for review on every WhatsApp inbox of every account,
# after removing the previous version of the message when it was edited
class Facebook::LeadAds::SubmitMessageTemplatesJob < ApplicationJob
  queue_as :low

  def perform(previous_template_name = nil)
    Facebook::LeadAds::WhatsappTemplate.whatsapp_inboxes.each do |inbox|
      template = Facebook::LeadAds::WhatsappTemplate.new(inbox: inbox)
      delete_previous(template, previous_template_name) if previous_template_name
      template.submit
    rescue StandardError => e
      Rails.logger.error("Lead message template submission failed for inbox #{inbox.id}: #{e.message}")
    end
  end

  private

  def delete_previous(template, name)
    template.delete(name)
  rescue StandardError => e
    Rails.logger.error("Lead message template removal failed for inbox #{template.inbox.id}: #{e.message}")
  end
end
