import { computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

export const useLeadsAccess = () => {
  const route = useRoute();
  const router = useRouter();
  const inboxes = useMapGetter('inboxes/getInboxes');
  const getAccount = useMapGetter('accounts/getAccount');
  const isFeatureEnabled = useMapGetter('accounts/isFeatureEnabledonAccount');
  const accountId = computed(() => route.params.accountId);

  const isLoaded = computed(
    () => !!getAccount.value(accountId.value).id && inboxes.value.length > 0
  );
  const hasAccess = computed(
    () =>
      inboxes.value.some(
        inbox => inbox.channel_type === 'Channel::FacebookPage'
      ) && isFeatureEnabled.value(accountId.value, FEATURE_FLAGS.FACEBOOK_LEADS)
  );

  watch(
    [isLoaded, hasAccess],
    () => {
      if (isLoaded.value && !hasAccess.value) {
        router.replace(frontendURL(`accounts/${accountId.value}/dashboard`));
      }
    },
    { immediate: true }
  );
};
