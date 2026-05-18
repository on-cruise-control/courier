<script setup>
import { computed } from 'vue';
import { useChannelIcon } from 'dashboard/components-next/icon/provider';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const inboxDetails = computed(() => props.inbox || {});

const channelImageSrc = computed(() => {
  const type = inboxDetails.value.channel_type;
  const provider = inboxDetails.value.provider;

  if (type === 'Channel::Email' && provider === 'google') {
    return '/assets/images/dashboard/channels/google.png';
  }
  if (type === 'Channel::Email' && provider === 'microsoft') {
    return '/assets/images/dashboard/channels/microsoft.png';
  }

  switch (type) {
    case 'Channel::Api':
      return '/assets/images/dashboard/channels/api.png';
    case 'Channel::Email':
      return '/assets/images/dashboard/channels/email.png';
    case 'Channel::FacebookPage':
      return '/integrations/channels/badges/messenger.png';
    case 'Channel::Instagram':
      return '/assets/images/dashboard/channels/instagram.png';
    case 'Channel::Whatsapp':
      return '/assets/images/dashboard/channels/whatsapp.png';
    case 'Channel::TwilioSms':
      return inboxDetails.value.medium === 'whatsapp'
        ? '/assets/images/dashboard/channels/whatsapp.png'
        : '/assets/images/dashboard/channels/sms.png';
    case 'Channel::Telegram':
      return '/assets/images/dashboard/channels/telegram.png';
    case 'Channel::Line':
      return '/assets/images/dashboard/channels/line.png';
    case 'Channel::TwitterProfile':
      return '/assets/images/dashboard/channels/twitter.png';
    case 'Channel::WebWidget':
      return '/assets/images/dashboard/channels/websitenew.png';
    case 'Channel::Sms':
      return '/assets/images/dashboard/channels/sms.png';
    case 'Channel::Tiktok':
      return '/assets/images/dashboard/channels/tiktok.png';
    case 'Channel::Voice':
      return '/assets/images/dashboard/channels/voice.png';
    default:
      return '';
  }
});

const channelIcon = useChannelIcon(inboxDetails);
</script>

<template>
  <img
    v-if="channelImageSrc"
    :src="channelImageSrc"
    :alt="inboxDetails.channel_type || 'channel'"
    class="w-full h-full object-contain"
  />
  <Icon v-else :icon="channelIcon" />
</template>
