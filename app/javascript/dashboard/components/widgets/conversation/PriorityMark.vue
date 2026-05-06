<script>
import { CONVERSATION_PRIORITY } from '../../../../shared/constants/messages';

export default {
  name: 'PriorityMark',
  props: {
    priority: {
      type: String,
      default: '',
      validate: value =>
        [...Object.values(CONVERSATION_PRIORITY), ''].includes(value),
    },
    showLabel: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      CONVERSATION_PRIORITY,
    };
  },
  computed: {
    tooltipText() {
      return this.$t(
        `CONVERSATION.PRIORITY.OPTIONS.${this.priority.toUpperCase()}`
      );
    },
    isUrgent() {
      return this.priority === CONVERSATION_PRIORITY.URGENT;
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <span
    v-if="priority"
    v-tooltip="!showLabel ? { content: tooltipText, delay: { show: 1500, hide: 0 }, hideOnClick: true } : undefined"
    class="shrink-0 rounded-sm inline-flex items-center gap-0.5 h-3.5"
    :class="{
      'bg-n-ruby-4 text-n-ruby-10': isUrgent,
      'bg-n-slate-4 text-n-slate-11': !isUrgent,
      'px-1': showLabel,
      'justify-center w-3.5': !showLabel,
    }"
  >
    <fluent-icon
      :icon="`priority-${priority.toLowerCase()}`"
      :size="isUrgent ? 12 : 14"
      class="flex-shrink-0"
      view-box="0 0 14 14"
    />
    <span v-if="showLabel" class="text-[10px] font-semibold leading-none capitalize">
      {{ priority }}
    </span>
  </span>
</template>
