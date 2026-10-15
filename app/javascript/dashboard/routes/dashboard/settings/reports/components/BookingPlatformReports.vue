<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store.js';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import { isChannelActive } from 'dashboard/routes/dashboard/settings/inbox/helpers/channelAvailability';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CustomReportContainer from 'dashboard/custom/reports/CustomReportContainer.vue';
import ReportContainer from '../ReportContainer.vue';
import {
  BOOKING_PLATFORMS,
  buildBookingReportKeys,
} from '../helpers/bookingStatsHelper';

const props = defineProps({
  type: { type: String, required: true },
  groupBy: { type: Object, default: () => ({}) },
  accountSummaryKey: { type: String, required: true },
  summaryFetchingKey: { type: String, required: true },
  isCustomUi: { type: Boolean, default: false },
});

const store = useStore();
const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute, currentAccount } = useAccount();
const inboxes = useMapGetter('inboxes/getInboxes');
const accountReports = useMapGetter('getAccountReports');

const container = computed(() =>
  props.isCustomUi ? CustomReportContainer : ReportContainer
);

const totalFor = platform =>
  Object.values(buildBookingReportKeys(props.type, platform)).reduce(
    (sum, metric) =>
      sum +
      (accountReports.value.data[metric] || []).reduce(
        (count, point) => count + point.value,
        0
      ),
    0
  );

// Channels with the most activity first, then connected ones, then the default order
const platforms = computed(() =>
  BOOKING_PLATFORMS.map((platform, index) => ({
    ...platform,
    index,
    total: totalFor(platform.key),
    isConnected: inboxes.value.some(platform.hasInbox),
    reportKeys: buildBookingReportKeys(props.type, platform.key),
  })).sort(
    (a, b) =>
      b.total - a.total ||
      Number(b.isConnected) - Number(a.isConnected) ||
      a.index - b.index
  )
);

const infoNamespace = computed(() =>
  props.type === 'booking' ? 'BOOKINGS_REPORTS' : 'HANDOFF_REPORTS'
);

const subtitlesFor = platform => {
  const name = t(`BOOKING_PLATFORM_REPORTS.PLATFORMS.${platform.labelKey}`);
  return {
    LINKS_SENT: t(`${infoNamespace.value}.PLATFORM_INFO.LINKS_SENT`, {
      platform: name,
    }),
    FORMS_COMPLETED: t(`${infoNamespace.value}.PLATFORM_INFO.FORMS_COMPLETED`, {
      platform: name,
    }),
  };
};

// Open the channel's own setup page when it can be added, otherwise the channel list
const connectInbox = channel => {
  const isAvailable = isChannelActive(channel, currentAccount.value.features);
  router.push(
    isAvailable
      ? accountScopedRoute('settings_inboxes_page_channel', {
          sub_page: channel,
        })
      : accountScopedRoute('settings_inbox_new')
  );
};

// Always refresh inboxes; until they load we can't tell if a channel is connected
const isLoadingInboxes = ref(true);

onMounted(async () => {
  await store.dispatch('inboxes/get');
  isLoadingInboxes.value = false;
});
</script>

<template>
  <div class="flex flex-col mt-3 gap-2">
    <section v-for="platform in platforms" :key="platform.key">
      <h3 class="mb-2 text-md font-semibold text-n-slate-12">
        {{ $t(`BOOKING_PLATFORM_REPORTS.PLATFORMS.${platform.labelKey}`) }}
      </h3>
      <component
        :is="container"
        v-if="platform.isConnected"
        :group-by="groupBy"
        :report-keys="platform.reportKeys"
        :subtitles="subtitlesFor(platform)"
        :account-summary-key="accountSummaryKey"
        :summary-fetching-key="summaryFetchingKey"
      />
      <div
        v-else-if="isLoadingInboxes"
        class="flex items-center justify-center px-6 py-5 mb-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
      >
        <Spinner />
      </div>
      <div
        v-else
        class="flex items-center justify-between gap-4 px-6 py-5 mb-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
      >
        <span class="text-sm text-n-slate-11">
          {{ $t('BOOKING_PLATFORM_REPORTS.NO_INBOX') }}
        </span>
        <Button sm solid blue @click="connectInbox(platform.key)">
          {{ $t('BOOKING_PLATFORM_REPORTS.CONNECT_INBOX') }}
        </Button>
      </div>
    </section>
  </div>
</template>
