<script setup>
import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMapGetter } from 'dashboard/composables/store';
import { useWindowSize } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import wootConstants from 'dashboard/constants/globals';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import ConversationSummaryPanel from './ConversationSummaryPanel.vue';
import CustomConversationSummaryPanel from './CustomConversationSummaryPanel.vue';

const props = defineProps({
  customUi: {
    type: Boolean,
    default: false,
  },
});

const { width: windowWidth } = useWindowSize();
const { uiSettings, updateUISettings } = useUISettings();
const currentChat = useMapGetter('getSelectedChat');
// CUSTOM UI
const currentAccountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const isCustomUIEnabled = computed(() => {
  if (props.customUi) return true;

  return isFeatureEnabledonAccount.value(
    currentAccountId.value,
    FEATURE_FLAGS.CUSTOM_UI
  );
});

const isSmallScreen = computed(
  () => windowWidth.value < wootConstants.SMALL_SCREEN_BREAKPOINT
);

const isConversationSummaryOpen = computed(
  () => uiSettings.value.is_conversation_summary_open
);

const shouldShowPanel = computed(() => {
  return isConversationSummaryOpen.value && currentChat.value.id;
});

const basePanelClasses = [
  'bg-n-background h-full overflow-hidden flex flex-col fixed top-0',
  'ltr:right-0 rtl:left-0 z-40 w-full max-w-sm transition-transform',
  'duration-300 ease-in-out md:static ltr:border-l rtl:border-r border-n-weak',
];

const panelClass = computed(() =>
  isCustomUIEnabled.value
    ? [
        ...basePanelClasses,
        'md:w-[360px] md:min-w-[360px] shadow-none custom-ui-font',
      ]
    : [
        ...basePanelClasses,
        'md:w-[320px] md:min-w-[320px] 2xl:min-w-[360px] 2xl:w-[360px]',
        'shadow-lg md:shadow-none',
      ]
);

const closePanel = () => {
  if (isSmallScreen.value && isConversationSummaryOpen.value) {
    updateUISettings({
      is_conversation_summary_open: false,
    });
  }
};
</script>

<template>
  <div
    v-if="shouldShowPanel"
    v-on-click-outside="() => closePanel()"
    :class="[
      panelClass,
      {
        'md:flex': shouldShowPanel,
        'md:hidden': !shouldShowPanel,
      },
    ]"
  >
  <!-- CUSTOM UI -->
    <CustomConversationSummaryPanel
      v-if="isCustomUIEnabled"
      :conversation-id="currentChat.id"
    />
    <!-- CUSTOM UI -->
    <ConversationSummaryPanel v-else :conversation-id="currentChat.id" />
  </div>
  <template v-else />
</template>
