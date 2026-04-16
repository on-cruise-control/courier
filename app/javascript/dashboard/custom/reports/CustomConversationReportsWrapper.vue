<script>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store.js';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import ConversationReports from 'dashboard/routes/dashboard/settings/reports/Index.vue';
import CustomConversationReports from './CustomConversationReports.vue';

export default {
  name: 'ConversationReportsWrapper',
  components: {
    ConversationReports,
    CustomConversationReports,
  },
  setup() {
    const isFeatureEnabledonAccount = useMapGetter(
      'accounts/isFeatureEnabledonAccount'
    );
    const currentAccountId = useMapGetter('getCurrentAccountId');

    const isCustomUI = computed(() => {
      return isFeatureEnabledonAccount.value(
        currentAccountId.value,
        FEATURE_FLAGS.CUSTOM_UI
      );
    });

    return { isCustomUI };
  },
};
</script>

<template>
  <CustomConversationReports v-if="isCustomUI" />
  <ConversationReports v-else />
</template>
