require 'rails_helper'

RSpec.describe SocialLinkParser do
  # Create a test class that includes the module to test its methods
  let(:test_class) do
    Class.new do
      include SocialLinkParser
    end
  end

  let(:instance) { test_class.new }

  describe '#extract_social_from_links' do
    context 'with various social media links' do
      it 'extracts WhatsApp handle' do
        links = ['https://wa.me/1234567890']
        result = instance.send(:extract_social_from_links, links)
        expect(result[:whatsapp]).to eq('1234567890')
      end

      it 'extracts Facebook handle' do
        links = ['https://facebook.com/myprofile']
        result = instance.send(:extract_social_from_links, links)
        expect(result[:facebook]).to eq('myprofile')
      end

      it 'extracts Instagram handle' do
        links = ['https://instagram.com/myprofile']
        result = instance.send(:extract_social_from_links, links)
        expect(result[:instagram]).to eq('myprofile')
      end

      it 'extracts Telegram handle' do
        links = ['https://t.me/myprofile']
        result = instance.send(:extract_social_from_links, links)
        expect(result[:telegram]).to eq('myprofile')
      end

      it 'extracts Line handle from path' do
        links = ['https://line.me/myprofile']
        result = instance.send(:extract_social_from_links, links)
        expect(result[:line]).to eq('myprofile')
      end

      it 'extracts TikTok handle' do
        links = ['https://tiktok.com/@myprofile']
        result = instance.send(:extract_social_from_links, links)
        expect(result[:tiktok]).to eq('@myprofile')
      end
    end

    context 'with multiple links' do
      it 'extracts multiple handles' do
        links = [
          'https://facebook.com/myprofile',
          'https://instagram.com/myprofile'
        ]
        result = instance.send(:extract_social_from_links, links)
        expect(result[:facebook]).to eq('myprofile')
        expect(result[:instagram]).to eq('myprofile')
      end
    end

    context 'with invalid links' do
      it 'returns nil for unsupported platforms' do
        links = ['https://example.com/profile']
        result = instance.send(:extract_social_from_links, links)
        expect(result.values).to all(be_nil)
      end

      it 'handles malformed URLs gracefully' do
        links = ['not a valid url']
        result = instance.send(:extract_social_from_links, links)
        expect(result.values).to all(be_nil)
      end
    end
  end

  describe '#find_social_handle' do
    context 'with matching links' do
      it 'finds handle for platform' do
        links = ['https://facebook.com/myprofile']
        result = instance.send(:find_social_handle, links, :facebook, %w[facebook.com])
        expect(result).to eq('myprofile')
      end
    end

    context 'with non-matching links' do
      it 'returns nil' do
        links = ['https://example.com/profile']
        result = instance.send(:find_social_handle, links, :facebook, %w[facebook.com])
        expect(result).to be_nil
      end
    end
  end

  describe '#match_social_domain?' do
    context 'with exact match' do
      it 'returns true' do
        result = instance.send(:match_social_domain?, 'facebook.com', 'facebook.com')
        expect(result).to be true
      end
    end

    context 'with subdomain match' do
      it 'returns true' do
        result = instance.send(:match_social_domain?, 'www.facebook.com', 'facebook.com')
        expect(result).to be true
      end
    end

    context 'with non-match' do
      it 'returns false' do
        result = instance.send(:match_social_domain?, 'example.com', 'facebook.com')
        expect(result).to be false
      end
    end

    context 'with blank host' do
      it 'returns false' do
        result = instance.send(:match_social_domain?, nil, 'facebook.com')
        expect(result).to be false
      end
    end
  end

  describe '#parse_social_handle' do
    context 'with standard social link' do
      it 'extracts handle from path' do
        uri = URI.parse('https://facebook.com/myprofile')
        result = instance.send(:parse_social_handle, :facebook, uri)
        expect(result).to eq('myprofile')
      end
    end

    context 'with share URLs' do
      it 'returns nil for share URLs' do
        uri = URI.parse('https://facebook.com/sharer.php?u=test')
        result = instance.send(:parse_social_handle, :facebook, uri)
        expect(result).to be_nil
      end
    end

    context 'with WhatsApp phone number' do
      it 'extracts phone number' do
        uri = URI.parse('https://wa.me/1234567890')
        result = instance.send(:parse_social_handle, :whatsapp, uri)
        expect(result).to eq('1234567890')
      end
    end

    context 'with WhatsApp API URL' do
      it 'extracts phone from query parameter' do
        uri = URI.parse('https://api.whatsapp.com/send?phone=1234567890')
        result = instance.send(:parse_social_handle, :whatsapp, uri)
        expect(result).to eq('1234567890')
      end
    end
  end

  describe '#extract_whatsapp_phone' do
    context 'with phone in path' do
      it 'extracts phone from path' do
        uri = URI.parse('https://wa.me/1234567890')
        result = instance.send(:extract_whatsapp_phone, uri)
        expect(result).to eq('1234567890')
      end
    end

    context 'with phone in query parameter' do
      it 'extracts phone from query' do
        uri = URI.parse('https://api.whatsapp.com/send?phone=1234567890')
        result = instance.send(:extract_whatsapp_phone, uri)
        expect(result).to eq('1234567890')
      end
    end

    context 'with formatted phone number' do
      it 'removes non-digit characters' do
        uri = URI.parse('https://wa.me/+1-234-567-8900')
        result = instance.send(:extract_whatsapp_phone, uri)
        expect(result).to eq('12345678900')
      end
    end
  end
end
