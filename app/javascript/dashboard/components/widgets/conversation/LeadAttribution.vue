<script setup>
import { computed } from 'vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ContactDetailsItem from 'dashboard/routes/dashboard/conversation/ContactDetailsItem.vue';

const props = defineProps({
  leadAttribution: {
    type: Object,
    default: () => ({}),
  },
  channelType: {
    type: String,
    default: '',
  },
  loading: {
    type: Boolean,
    default: false,
  },
  error: {
    type: Boolean,
    default: false,
  },
});

const SOCIAL_CHANNELS = ['Channel::FacebookPage', 'Channel::Instagram'];

const isSocialChannel = computed(() =>
  SOCIAL_CHANNELS.includes(props.channelType)
);

const fields = computed(() => {
  if (isSocialChannel.value) {
    return [
      {
        key: 'ad_title',
        title: 'CONVERSATION_SIDEBAR.LEAD_ATTRIBUTION.AD_TITLE',
      },
    ];
  }
  return [
    {
      key: 'utm_source',
      title: 'CONVERSATION_SIDEBAR.LEAD_ATTRIBUTION.UTM_SOURCE',
    },
    {
      key: 'utm_medium',
      title: 'CONVERSATION_SIDEBAR.LEAD_ATTRIBUTION.UTM_MEDIUM',
    },
    {
      key: 'utm_campaign',
      title: 'CONVERSATION_SIDEBAR.LEAD_ATTRIBUTION.UTM_CAMPAIGN',
    },
    {
      key: 'utm_content',
      title: 'CONVERSATION_SIDEBAR.LEAD_ATTRIBUTION.UTM_CONTENT',
    },
    {
      key: 'utm_term',
      title: 'CONVERSATION_SIDEBAR.LEAD_ATTRIBUTION.UTM_TERM',
    },
    {
      key: 'referer_url',
      title: 'CONVERSATION_SIDEBAR.LEAD_ATTRIBUTION.REFERER_URL',
    },
  ];
});

const visibleFields = computed(() =>
  fields.value.filter(field => !!props.leadAttribution[field.key])
);
</script>

<template>
  <div class="conversation--details">
    <div v-if="loading" class="flex justify-center items-center p-4">
      <Spinner size="32" class="text-n-brand" />
    </div>
    <div v-else-if="error" class="p-3 text-center text-n-ruby-12">
      {{ $t('CONVERSATION_SIDEBAR.LEAD_ATTRIBUTION.ERROR') }}
    </div>
    <p v-else-if="!visibleFields.length" class="p-3 text-center">
      {{ $t('CONVERSATION_SIDEBAR.LEAD_ATTRIBUTION.NO_RECORDS_FOUND') }}
    </p>
    <div
      v-else
      class="last:rounded-b-lg [&>*:nth-child(odd)]:!bg-n-surface-1 [&>*:nth-child(even)]:!bg-n-slate-1 dark:[&>*:nth-child(odd)]:!bg-n-surface-2 dark:[&>*:nth-child(even)]:!bg-n-surface-1"
    >
      <div
        v-for="(field, index) in visibleFields"
        :key="field.key"
        class="relative border-b border-n-weak/50 dark:border-n-weak/90"
        :class="{
          'last:border-transparent dark:last:border-transparent':
            index === visibleFields.length - 1,
        }"
      >
        <ContactDetailsItem
          :title="$t(field.title)"
          :value="leadAttribution[field.key]"
        >
          <a
            v-if="field.key === 'referer_url'"
            :href="leadAttribution[field.key]"
            rel="noopener noreferrer nofollow"
            target="_blank"
            class="text-n-brand"
          >
            {{ leadAttribution[field.key] }}
          </a>
        </ContactDetailsItem>
      </div>
    </div>
  </div>
</template>
