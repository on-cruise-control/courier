<script setup>
import { computed } from 'vue';

import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import Dashboard from './Dashboard.vue';
import CustomDashboard from '../../custom/CustomDashboard.vue';

const { accountId } = useAccount();
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const isCustomUIEnabled = computed(() => {
  if (!accountId.value) return false;
  return isFeatureEnabledonAccount.value(
    accountId.value,
    FEATURE_FLAGS.CUSTOM_UI
  );
});
</script>

<template>
  <CustomDashboard v-if="isCustomUIEnabled" />
  <Dashboard v-else />
</template>
