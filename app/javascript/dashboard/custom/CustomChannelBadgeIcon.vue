<script setup>
import { computed } from 'vue';
import { useChannelIcon } from 'dashboard/components-next/icon/provider';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
  sizeClass: {
    type: String,
    default: 'size-4',
  },
});

const inboxDetails = computed(() => props.inbox || {});

const badgeImageSrc = computed(() => {
  const type = inboxDetails.value.channel_type;
  const provider = inboxDetails.value.provider;

  if (type === 'Channel::Email' && provider === 'google') {
    return '/assets/images/dashboard/channels/google.png';
  }
  if (type === 'Channel::Email' && provider === 'microsoft') {
    return '/assets/images/dashboard/channels/microsoft.png';
  }

  switch (type) {
    case 'Channel::FacebookPage':
      return '/integrations/channels/badges/messenger.png';
    case 'Channel::Instagram':
      return '/integrations/channels/badges/instagram-dm.png';
    case 'Channel::Whatsapp':
      return '/integrations/channels/badges/whatsapp.png';
    case 'Channel::TwilioSms':
      return inboxDetails.value.medium === 'whatsapp'
        ? '/integrations/channels/badges/whatsapp.png'
        : '/integrations/channels/badges/sms.png';
    case 'Channel::Telegram':
      return '/integrations/channels/badges/telegram.png';
    case 'Channel::Line':
      return '/integrations/channels/badges/line.png';
    case 'Channel::TwitterProfile':
      return '/integrations/channels/badges/twitter-dm.png';
    case 'Channel::Sms':
      return '/integrations/channels/badges/sms.png';
    case 'Channel::Tiktok':
      return '/integrations/channels/badges/tiktok.png';
    case 'Channel::WebWidget':
      return '/assets/images/dashboard/channels/website.png';
    case 'Channel::Api':
      return '/assets/images/dashboard/channels/api.png';
    case 'Channel::Email':
      return '/assets/images/dashboard/channels/email.png';
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
    v-if="badgeImageSrc"
    :src="badgeImageSrc"
    :alt="inboxDetails.channel_type || 'channel'"
    class="object-contain"
    :class="sizeClass"
  />
  <Icon v-else :icon="channelIcon" :class="sizeClass" />
</template>
