<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useUISettings } from 'dashboard/composables/useUISettings';
import CustomConversationSummary from './CustomConversationSummary.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();

const { updateUISettings } = useUISettings();
const conversationSummaryRef = ref(null);

const title = computed(() => t('CONVERSATION.SIDEBAR.SUMMARY'));

const refreshSummary = () => {
  conversationSummaryRef.value?.fetchSummary(true);
};

const closePanel = () => {
  updateUISettings({
    is_conversation_summary_open: false,
  });
};
</script>

<template>
  <div class="flex flex-col h-full w-full bg-n-surface-1 custom-ui-font">
    <div class="flex items-center justify-between h-14 px-5">
      <h2
        class="max-w-24 text-[11px] font-black uppercase leading-4 tracking-wide text-n-slate-12"
      >
        {{ title }}
      </h2>
      <div class="flex items-center gap-3">
        <button
          v-tooltip.bottom="t('CONVERSATION.SUMMARY.REFRESH_TOOLTIP')"
          type="button"
          class="flex items-center gap-1 text-xs font-medium text-n-slate-12 hover:text-n-brand"
          @click="refreshSummary"
        >
          <i class="i-lucide-refresh-cw size-3.5" />
          <span>{{ t('CONVERSATION.SUMMARY.REFRESH_LABEL') }}</span>
        </button>
        <Button
          v-tooltip.bottom="$t('GENERAL.CLOSE')"
          icon="i-lucide-panel-left-close"
          ghost
          sm
          class="!text-n-slate-12 hover:!bg-transparent hover:!text-n-brand"
          @click="closePanel"
        />
      </div>
    </div>
    
    <div class="flex-1 overflow-y-auto">
      <CustomConversationSummary
        ref="conversationSummaryRef"
        :conversation-id="conversationId"
      />
    </div>
  </div>
</template>
