require 'rails_helper'

RSpec.describe Stark::MessageHandler do
  let(:handler) do
    Class.new do
      include Stark::MessageHandler

      attr_accessor :current_conversation, :event_data, :agent_bot

      def initialize
        @current_conversation = nil
        @event_data = {}
        @agent_bot = nil
      end
    end.new
  end

  describe '#response_valid?' do
    it 'returns true when response has content' do
      expect(handler.response_valid?({ 'content' => 'Hello' })).to be true
    end

    it 'returns true when response has action' do
      expect(handler.response_valid?({ 'action' => 'some_action' })).to be true
    end

    it 'returns true when response has attachments' do
      expect(handler.response_valid?({ 'attachments' => [{ 'url' => 'http://example.com' }] })).to be true
    end

    it 'returns false when response is empty' do
      expect(handler.response_valid?({})).to be false
    end
  end

  describe '#create_bot_response_message with vehicle_url' do
    let(:account) { create(:account) }
    let(:agent_bot) { create(:agent_bot, account: account) }
    let(:attachment) do
      { 'content' => '2026 Jeep Grand Cherokee', 'url' => 'https://example.com/car.jpg',
        'vehicle_id' => 'abc', 'vehicle_url' => 'https://staging.getcruisecontrol.com/v/abc' }
    end

    before do
      handler.agent_bot = agent_bot
      allow(handler).to receive(:download_image_blob).and_return(nil)
    end

    def conversation_for(inbox, type = nil)
      contact_inbox = create(:contact_inbox, inbox: inbox)
      create(:conversation, account: account, inbox: inbox, contact_inbox: contact_inbox,
                            additional_attributes: { 'type' => type }.compact)
    end

    shared_examples 'sends a vehicle template' do
      it 'creates a cards message with a web_url View Vehicle button' do
        conversation = conversation_for(inbox)
        handler.create_bot_response_message(conversation, 'Here you go', [attachment])

        card = conversation.messages.find_by(content_type: :cards)
        action = card.content_attributes['items'].first['actions'].first
        expect(action).to include('type' => 'web_url', 'text' => 'View Vehicle', 'uri' => attachment['vehicle_url'])
        expect(card.content_attributes['items'].first['media_url']).to eq(attachment['url'])
      end

      it 'falls back to image + title when vehicle_url is invalid' do
        conversation = conversation_for(inbox)
        allow(URI).to receive(:open).and_return(StringIO.new('img').tap { |io| io.define_singleton_method(:content_type) { 'image/jpeg' } })
        handler.create_bot_response_message(conversation, nil, [attachment.merge('vehicle_url' => 'javascript:alert(1)')])

        expect(conversation.messages.where(content_type: :cards)).to be_empty
        expect(conversation.messages.pluck(:content).compact).to include(attachment['content'])
      end

      it 'splits more than 10 vehicles into multiple templates' do
        conversation = conversation_for(inbox)
        handler.create_bot_response_message(conversation, nil, Array.new(11) { attachment })

        expect(conversation.messages.where(content_type: :cards).count).to eq(2)
      end
    end

    context 'when instagram dm' do
      let(:inbox) { create(:inbox, account: account, channel: create(:channel_instagram, account: account)) }

      it_behaves_like 'sends a vehicle template'
    end

    context 'when facebook messenger' do
      let(:inbox) { create(:inbox, account: account, channel: create(:channel_facebook_page, account: account)) }

      it_behaves_like 'sends a vehicle template'
    end

    context 'when web widget' do
      let(:inbox) { create(:inbox, account: account) }

      it 'opens vehicle_url from a single View Details button' do
        conversation = conversation_for(inbox)
        handler.create_bot_response_message(conversation, nil, [attachment])

        actions = conversation.messages.find_by(content_type: :cards).content_attributes['items'].first['actions']
        expect(actions).to eq([{ 'text' => 'View Details', 'type' => 'link', 'uri' => attachment['vehicle_url'] }])
      end

      it 'keeps the in-widget View Details when vehicle_url is missing' do
        conversation = conversation_for(inbox)
        handler.create_bot_response_message(conversation, nil, [attachment.except('vehicle_url')])

        actions = conversation.messages.find_by(content_type: :cards).content_attributes['items'].first['actions']
        expect(actions).to eq([{ 'text' => 'View Details', 'type' => 'view_vehicle', 'payload' => 'abc' }])
      end
    end
  end
end
