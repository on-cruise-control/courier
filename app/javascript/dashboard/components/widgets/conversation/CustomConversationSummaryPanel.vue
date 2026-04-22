<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useUISettings } from 'dashboard/composables/useUISettings';
import CustomConversationSummary from './CustomConversationSummary.vue';
import SidebarActionsHeader from 'dashboard/components-next/SidebarActionsHeader.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();

const { updateUISettings } = useUISettings();
const conversationSummaryRef = ref(null);

// Computed property to handle header buttons
const headerButtons = computed(() => [
  {
    key: 'refresh',
    icon: 'i-lucide-refresh-cw',
    label: t('CONVERSATION.SUMMARY.REFRESH_LABEL'),
    tooltip: t('CONVERSATION.SUMMARY.REFRESH_TOOLTIP'),
    disabled: false,
  },
]);

const handleHeaderAction = key => {
  if (key === 'refresh') {
    conversationSummaryRef.value?.fetchSummary(true);
  }
};

const closePanel = () => {
  updateUISettings({
    is_conversation_summary_open: false,
  });
};
</script>

<template>
  <div class="flex flex-col h-full w-full bg-n-background custom-ui-font">
    <SidebarActionsHeader
      :title="$t('CONVERSATION.SIDEBAR.SUMMARY')"
      :buttons="headerButtons"
      close-icon="i-lucide-panel-left-close"
      class="!bg-transparent !border-none !px-5 !pt-4"
      @click="handleHeaderAction"
      @close="closePanel"
    />
    
    <div class="flex-1 overflow-y-auto">
      <CustomConversationSummary
        ref="conversationSummaryRef"
        :conversation-id="conversationId"
      />
    </div>
  </div>
</template>

<style lang="scss" scoped>
.custom-ui-font {
  font-family: 'Outfit', sans-serif !important;
}

::v-deep {
  h2, .text-n-slate-12 {
     font-family: 'Outfit', sans-serif !important;
     @apply font-bold text-sm uppercase tracking-wide;
  }
}
</style>
