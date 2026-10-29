class SendTemplateDmJob < ApplicationJob
  queue_as :default

  TEMPLATE_MESSAGE = 'Hey, thanks for your comment! We're here to help if you have any questions.'

  def perform(contact_inbox_id, conversation, comment_id)
    Rails.logger.info "=================== SendTemplateDmJob START =======comment_id #{comment_id}============"

    contact_inbox = ContactInbox.find_by(id: contact_inbox_id)
    unless contact_inbox
      Rails.logger.error "❌ ContactInbox not found for ID: #{contact_inbox_id}"
      return
    end

    if conversation.nil?
      Rails.logger.error '❌ Conversation is nil'
      return
    end

    account = contact_inbox.inbox.account
    unless account
      Rails.logger.error "❌ Account not found for ContactInbox ID: #{contact_inbox_id}"
      return
    end

    unless contact_inbox.inbox.comment_auto_reply_enabled?
      Rails.logger.info "⏸️ Comment auto reply disabled for inbox #{contact_inbox.inbox_id}, skipping template DM"
      return
    end

    contact = conversation.contact
    inbox = contact_inbox.inbox
    recipient_id = contact.get_source_id(inbox.id) if contact && inbox

    if recipient_id.blank?
      Rails.logger.error "❌ Missing recipient_id for conversation: #{conversation.id}"
      return
    end

    # One template DM per contact per post. Comments arriving together on the same post
    # each enqueue this job; the atomic write (Redis SET NX) lets exactly one job proceed.
    dm_lock_key = "template_dm_job_#{contact_inbox.id}_#{contact.id}_#{post_identifier(conversation)}"
    unless Rails.cache.write(dm_lock_key, true, expires_in: 5.minutes, unless_exist: true)
      Rails.logger.info "⏩ Duplicate template DM skipped for contact #{contact.id} on post #{post_identifier(conversation)}"
      return
    end

    case conversation.additional_attributes['type']
    when 'instagram_comments', 'instagram_dm'
      send_instagram_dm(contact_inbox, recipient_id, TEMPLATE_MESSAGE, comment_id, conversation)
    when 'facebook_comments', 'facebook_dm', 'feed_comments'
      send_facebook_dm(contact_inbox, recipient_id, TEMPLATE_MESSAGE, comment_id, conversation)
    else
      Rails.logger.warn "⚠️ Unsupported type for template DM: #{conversation.additional_attributes['type']}"
    end
  end

  private

  # Stable identifier for the post a comment belongs to: IG media id, or FB post id / permalink.
  # Falls back to 'unknown' so DMs still dedupe per contact when the post can't be determined.
  def post_identifier(conversation)
    attrs = conversation.additional_attributes || {}
    attrs['media_id'].presence || attrs['post_id'].presence || attrs['post_url'].presence || 'unknown'
  end

  def channel
    Channel::FacebookPage.find_by(id: contact_inbox.inbox.channel_id)
  end

  def find_existing_template_facebook_dm_conversation(_contact_inbox, contact, inbox, account)
    Conversation.joins(contact_inbox: { contact: :account }, inbox: :account)
                .where(
                  "conversations.contact_id = ? AND conversations.inbox_id = ? AND inboxes.account_id = ? AND conversations.additional_attributes->>'type' = ?",
                  contact.id,
                  inbox.id,
                  account.id,
                  'template_dm'
                )
                .last
  end

  def find_existing_template_insta_dm_conversation(_contact_inbox, contact, inbox, account)
    Conversation.joins(contact_inbox: { contact: :account }, inbox: :account)
                .where(
                  "conversations.contact_id = ? AND conversations.inbox_id = ? AND inboxes.account_id = ? AND conversations.additional_attributes->>'type' = ?",
                  contact.id,
                  inbox.id,
                  account.id,
                  'instagram_dm'
                )
                .last
  end

  def find_or_create_template_facebook_dm_conversation(contact_inbox, contact, inbox, account)
    template_dm_conversation = find_existing_template_facebook_dm_conversation(contact_inbox, contact, inbox, account)

    if template_dm_conversation.nil?
      Rails.logger.info "No existing conversation found, creating a new one for contact #{contact.id} in inbox #{inbox.id}"
      template_dm_conversation = Conversation.create!(
        contact: contact,
        inbox: inbox,
        account: account,
        contact_inbox: contact_inbox,
        additional_attributes: { 'type' => 'template_dm' }
      )
    else
      Rails.logger.info "Found existing conversation #{template_dm_conversation.id} for contact #{contact.id} in inbox #{inbox.id}"
    end

    template_dm_conversation
  end

  def find_or_create_template_insta_dm_conversation(contact_inbox, contact, inbox, account)
    template_dm_conversation = find_existing_template_insta_dm_conversation(contact_inbox, contact, inbox, account)

    if template_dm_conversation.nil?
      Rails.logger.info "No existing conversation found, creating a new one for contact #{contact.id} in inbox #{inbox.id}"
      template_dm_conversation = Conversation.create!(
        contact: contact,
        inbox: inbox,
        account: account,
        contact_inbox: contact_inbox,
        additional_attributes: { 'type' => 'instagram_dm' }
      )
    else
      Rails.logger.info "Found existing conversation #{template_dm_conversation.id} for contact #{contact.id} in inbox #{inbox.id}"
    end

    template_dm_conversation
  end

  def send_facebook_dm(contact_inbox, _recipient_id, template_message, comment_id, comment_conversation)
    channel = contact_inbox.inbox.channel
    access_token = channel.page_access_token
    page_id = channel.page_id
    app_secret = GlobalConfigService.load('FB_APP_SECRET', '')
    app_secret_proof = calculate_app_secret_proof(app_secret, access_token)

    query = { access_token: access_token }
    query[:appsecret_proof] = app_secret_proof if app_secret_proof.present?

    url = "https://graph.facebook.com/v23.0/#{page_id}/messages"

    body = {
      messaging_type: 'RESPONSE',
      recipient: { comment_id: comment_id },
      message: { text: template_message }
    }

    contact = contact_inbox.contact
    inbox = contact_inbox.inbox
    account = inbox.account
    post_id = post_identifier(comment_conversation)

    # Skip if a template DM has already been sent to this contact for this post
    existing_conversation = find_existing_template_facebook_dm_conversation(contact_inbox, contact, inbox, account)
    if dm_already_sent_for_post?(existing_conversation, post_id)
      Rails.logger.info "⏩ Skipping duplicate template DM - already sent to contact #{contact.id} for post #{post_id}"
      return
    end

    template_dm_conversation = contact.with_lock { find_or_create_template_facebook_dm_conversation(contact_inbox, contact, inbox, account) }
    stark_bot = AgentBot.find_by(bot_type: 'stark')

    message = template_dm_conversation.messages.create!(
      content: template_message,
      account: account,
      inbox: inbox,
      sender: stark_bot,
      message_type: :outgoing,
      private: false,
      source_id: 'pending_delivery',
      additional_attributes: { 'delivery_status' => 'sent' }
    )

    response = HTTParty.post(
      url,
      headers: { 'Content-Type' => 'application/json' },
      query: query,
      body: body.to_json
    )

    if response.code != 200 || response['error'].present?
      error = response['error'] || {}
      Messages::StatusUpdateService.new(message, 'failed', "#{error['code']} - #{error['message']}").perform
      Rails.logger.error "❌ Facebook DM Template API error: #{error.presence || response.body}"
      return
    end

    message.update!(source_id: response['message_id'])

    mark_dm_sent_for_post(template_dm_conversation, post_id)

    Rails.logger.info '✅ Facebook Template DM sent successfully'
  end

  def send_instagram_dm(contact_inbox, _recipient_id, template_message, comment_id, comment_conversation)
    channel = contact_inbox.inbox.channel
    access_token = channel.access_token
    page_id = channel.instagram_id

    url = "https://graph.instagram.com/v23.0/#{page_id}/messages"

    body = {
      recipient: { comment_id: comment_id },
      message: { text: template_message }
    }

    contact = contact_inbox.contact
    inbox = contact_inbox.inbox
    account = inbox.account
    post_id = post_identifier(comment_conversation)

    # Skip if a template DM has already been sent to this contact for this post
    existing_conversation = find_existing_template_insta_dm_conversation(contact_inbox, contact, inbox, account)
    if dm_already_sent_for_post?(existing_conversation, post_id)
      Rails.logger.info "⏩ Skipping duplicate template DM - already sent to contact #{contact.id} for post #{post_id}"
      return
    end

    template_dm_conversation = contact.with_lock { find_or_create_template_insta_dm_conversation(contact_inbox, contact, inbox, account) }
    stark_bot = AgentBot.find_by(bot_type: 'stark')

    message = template_dm_conversation.messages.create!(
      content: template_message,
      account: account,
      inbox: inbox,
      sender: stark_bot,
      message_type: :outgoing,
      private: false,
      source_id: 'pending_delivery',
      additional_attributes: { 'delivery_status' => 'sent' }
    )

    response = HTTParty.post(
      url,
      headers: { 'Content-Type' => 'application/json' },
      query: { access_token: access_token },
      body: body.to_json
    )

    if response.code != 200 || response['error'].present?
      error = response['error'] || {}
      Messages::StatusUpdateService.new(message, 'failed', "#{error['code']} - #{error['message']}").perform
      Rails.logger.error "❌ Instagram DM Template API error: #{error.presence || response.body}"
      return
    end

    message.update!(source_id: response['message_id'])

    mark_dm_sent_for_post(template_dm_conversation, post_id)

    Rails.logger.info '✅ Instagram Template DM sent successfully'
  end

  # Template DM conversations track which posts they've already replied to in
  # additional_attributes['dm_sent_post_ids'] (one entry per post).
  def dm_already_sent_for_post?(conversation, post_id)
    return false if conversation.nil?

    Array(conversation.additional_attributes['dm_sent_post_ids']).include?(post_id)
  end

  def mark_dm_sent_for_post(conversation, post_id)
    conversation.reload
    sent_post_ids = Array(conversation.additional_attributes['dm_sent_post_ids']) | [post_id]
    conversation.update!(
      additional_attributes: conversation.additional_attributes.merge('dm_sent_post_ids' => sent_post_ids)
    )
  end

  def calculate_app_secret_proof(app_secret, access_token)
    return nil if app_secret.blank? || access_token.blank?

    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), app_secret, access_token)
  end
end
