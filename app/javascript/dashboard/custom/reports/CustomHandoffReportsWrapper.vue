<script>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store.js';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import HandoffReports from 'dashboard/routes/dashboard/settings/reports/HandoffReports.vue';
import CustomHandoffReports from './CustomHandoffReports.vue';

export default {
  name: 'HandoffReportsWrapper',
  components: {
    HandoffReports,
    CustomHandoffReports,
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
  <CustomHandoffReports v-if="isCustomUI" />
  <HandoffReports v-else />
</template>
