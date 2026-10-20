// Whether a channel can be added for the account (feature enabled and app configured)
export const isChannelActive = (key, enabledFeatures = {}) => {
  if (Object.keys(enabledFeatures).length === 0) {
    return false;
  }
  if (key === 'website') {
    return enabledFeatures.channel_website;
  }
  if (key === 'facebook') {
    return enabledFeatures.channel_facebook && window.chatwootConfig?.fbAppId;
  }
  if (key === 'email') {
    return enabledFeatures.channel_email;
  }

  if (key === 'instagram') {
    return (
      enabledFeatures.channel_instagram && window.chatwootConfig?.instagramAppId
    );
  }

  if (key === 'tiktok') {
    return enabledFeatures.channel_tiktok && window.chatwootConfig?.tiktokAppId;
  }

  if (key === 'voice') {
    return enabledFeatures.channel_voice;
  }

  if (key === 'whatsapp_call') {
    return (
      enabledFeatures.channel_voice &&
      !!window.chatwootConfig?.whatsappAppId &&
      window.chatwootConfig.whatsappAppId !== 'none'
    );
  }

  return [
    'website',
    'twilio',
    'api',
    'whatsapp',
    'sms',
    'telegram',
    'line',
    'instagram',
    'tiktok',
    'voice',
  ].includes(key);
};
