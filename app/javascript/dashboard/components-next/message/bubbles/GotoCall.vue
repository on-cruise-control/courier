<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from '../provider.js';
import { formatDuration } from 'shared/helpers/timeHelper';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import AudioChip from 'next/message/chips/Audio.vue';

const { t } = useI18n();
const { contentAttributes, attachments } = useMessageContext();

const data = computed(() => contentAttributes.value?.data || {});
const isOutbound = computed(() => data.value.callDirection === 'outbound');
const isUnanswered = computed(() =>
  ['no-answer', 'busy'].includes(data.value.status)
);
const isBusy = computed(() => data.value.status === 'busy');

const audio = computed(() => attachments.value?.[0]);

const isLive = computed(() =>
  ['ringing', 'in-progress'].includes(data.value.status)
);

const audioTitle = computed(() =>
  data.value.voicemailId
    ? t('CONVERSATION.VOICE_CALL.VOICEMAIL')
    : t('CONVERSATION.VOICE_CALL.RECORDING')
);

const label = computed(() => {
  const { status } = data.value;
  if (status === 'completed') return t('CONVERSATION.VOICE_CALL.CALL_ENDED');
  if (status === 'in-progress')
    return t('CONVERSATION.VOICE_CALL.CALL_IN_PROGRESS');
  if (isBusy.value) return t('CONVERSATION.VOICE_CALL.BUSY');
  if (isUnanswered.value) {
    return isOutbound.value
      ? t('CONVERSATION.VOICE_CALL.NO_ANSWER')
      : t('CONVERSATION.VOICE_CALL.MISSED_CALL');
  }
  return t('CONVERSATION.VOICE_CALL.RINGING');
});

const subtext = computed(() => {
  if (data.value.status === 'completed')
    return formatDuration(data.value.durationSeconds);
  if (isUnanswered.value && isOutbound.value)
    return t('CONVERSATION.VOICE_CALL.NOT_ANSWERED');
  return '';
});

const iconClass = computed(() => {
  if (isLive.value) return 'bg-n-teal-9 !text-white';
  if (isUnanswered.value && !isOutbound.value)
    return 'bg-n-alpha-2 text-n-ruby-9';
  return 'bg-n-alpha-2 text-n-slate-12';
});

const iconName = computed(() => {
  if (isUnanswered.value) return 'i-ph-phone-x-bold';
  return isOutbound.value
    ? 'i-ph-phone-outgoing-bold'
    : 'i-ph-phone-incoming-bold';
});
</script>

<template>
  <BaseBubble class="!p-3 !max-w-md min-w-[240px]" hide-meta>
    <div class="flex gap-2.5 items-center">
      <div
        class="flex justify-center items-center rounded-xl size-11 shrink-0"
        :class="iconClass"
      >
        <Icon class="size-4" :icon="iconName" />
      </div>
      <div class="flex flex-col min-w-0">
        <span class="font-display text-sm font-medium leading-tight truncate">
          {{ label }}
        </span>
        <span v-if="subtext" class="text-sm leading-tight opacity-75">
          {{ subtext }}
        </span>
      </div>
    </div>
    <template v-if="audio">
      <p class="mt-3 mb-1 text-xs font-medium opacity-75">{{ audioTitle }}</p>
      <AudioChip
        :attachment="audio"
        :show-transcribed-text="false"
        :class="
          isOutbound
            ? 'goto-audio-player !bg-[#fbfbfc] dark:!bg-n-alpha-white'
            : ''
        "
      />
    </template>
    <p v-if="data.transcript" class="mt-2 text-sm">
      {{ data.transcript }}
    </p>
  </BaseBubble>
</template>
