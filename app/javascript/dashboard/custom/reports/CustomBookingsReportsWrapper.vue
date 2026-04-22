<script>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store.js';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import BookingsReports from 'dashboard/routes/dashboard/settings/reports/BookingsReports.vue';
import CustomBookingsReports from './CustomBookingsReports.vue';

export default {
  name: 'BookingsReportsWrapper',
  components: {
    BookingsReports,
    CustomBookingsReports,
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
  <CustomBookingsReports v-if="isCustomUI" />
  <BookingsReports v-else />
</template>
