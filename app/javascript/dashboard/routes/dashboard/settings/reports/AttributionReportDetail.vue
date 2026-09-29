<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, onBeforeRouteLeave } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store.js';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import ReportHeader from './components/ReportHeader.vue';
import { ATTRIBUTION_DIMENSIONS as DIMENSIONS } from './attributionDimensions';
import { useAttributionFilterQuery } from './useAttributionFilterQuery';
import { attributionNavState } from './attributionNavigationState';

const route = useRoute();
const store = useStore();
const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const { buildFilterPayload } = useAttributionFilterQuery();

onBeforeRouteLeave(to => {
  if (to.name === 'attribution_reports') {
    attributionNavState.skipNextForceFetch = true;
  }
});

const dimension = computed(() =>
  DIMENSIONS.find(d => d.key === route.params.dimension)
);

const report = useMapGetter('getAttributionReport');
const isFetchingReport = useMapGetter('isFetchingAttributionReport');

const totals = computed(() => report.value?.totals || {});
const rows = computed(
  () => report.value?.breakdown?.[route.params.dimension] || []
);

const PAGE_SIZE = 12;
const currentPage = ref(1);
const paginatedRows = computed(() => {
  const start = (currentPage.value - 1) * PAGE_SIZE;
  return rows.value.slice(start, start + PAGE_SIZE);
});

watch(
  () => route.params.dimension,
  () => {
    currentPage.value = 1;
  }
);

onMounted(() => {
  store.dispatch('fetchAttributionValues');
  store.dispatch('fetchAttributionReport', buildFilterPayload()).catch(() => {
    useAlert(t('ATTRIBUTION_REPORTS.FETCHING_FAILED'));
  });
});
</script>

<template>
  <div v-if="dimension" class="flex flex-col h-screen">
    <ReportHeader
      :header-title="$t(`ATTRIBUTION_REPORTS.DIMENSIONS.${dimension.i18nKey}`)"
    />

    <div class="flex flex-col gap-3 mb-6">
      <router-link
        :to="accountScopedRoute('attribution_reports', {}, route.query)"
        class="flex items-center gap-1.5 text-sm text-n-blue-11 hover:underline w-fit"
      >
        <Icon icon="i-lucide-arrow-left" class="text-sm" />
        {{ $t('ATTRIBUTION_REPORTS.DETAIL.BACK') }}
      </router-link>

      <div class="flex items-center gap-6">
        <span class="flex items-center gap-1.5 text-sm text-n-slate-11">
          <Icon icon="i-lucide-users" class="text-sm text-n-slate-9" />
          {{ $t('ATTRIBUTION_REPORTS.DETAIL.CUSTOMERS') }}
          <span class="font-semibold text-n-slate-12 tabular-nums">
            {{ totals.customers || 0 }}
          </span>
        </span>

        <span class="flex items-center gap-1.5 text-sm text-n-slate-11">
          <Icon icon="i-lucide-calendar-check" class="text-sm text-n-slate-9" />
          {{ $t('ATTRIBUTION_REPORTS.DETAIL.BOOKINGS') }}
          <span class="font-semibold text-n-slate-12 tabular-nums">
            {{ totals.bookings || 0 }}
          </span>
        </span>
      </div>
    </div>

    <main class="flex-1 overflow-y-auto">
      <div class="flex flex-col gap-5 pb-6">
        <div
          v-if="isFetchingReport"
          class="flex items-center justify-center p-16"
        >
          <Spinner />
        </div>

        <template v-else>
          <div
            v-if="rows.length"
            class="rounded-xl border border-n-weak shadow-sm bg-n-solid-1 dark:bg-n-solid-2 overflow-hidden"
          >
            <div class="overflow-x-auto">
              <table class="w-full min-w-[560px] text-sm">
                <thead>
                  <tr
                    class="text-left text-xs text-n-slate-10 border-b border-n-weak dark:border-n-strong"
                  >
                    <th class="py-2.5 px-4 font-medium">
                      {{
                        $t(
                          `ATTRIBUTION_REPORTS.DIMENSIONS.${dimension.i18nKey}`
                        )
                      }}
                    </th>
                    <th class="py-2.5 px-4 font-medium text-right">
                      {{ $t('ATTRIBUTION_REPORTS.DETAIL.TABLE.CUSTOMERS') }}
                    </th>
                    <th class="py-2.5 px-4 font-medium text-right">
                      {{ $t('ATTRIBUTION_REPORTS.DETAIL.TABLE.CUSTOMER_PCT') }}
                    </th>
                    <th class="py-2.5 px-4 font-medium text-right">
                      {{ $t('ATTRIBUTION_REPORTS.DETAIL.TABLE.BOOKINGS') }}
                    </th>
                    <th class="py-2.5 px-4 font-medium text-right">
                      {{ $t('ATTRIBUTION_REPORTS.DETAIL.TABLE.BOOKING_PCT') }}
                    </th>
                  </tr>
                </thead>

                <tbody>
                  <tr
                    v-for="row in paginatedRows"
                    :key="row.value"
                    class="border-b border-n-weak last:border-b-0 transition-colors hover:bg-n-slate-2 dark:hover:bg-n-solid-3 dark:border-n-strong"
                  >
                    <td class="py-3 px-4">
                      <div class="flex items-center gap-2.5">
                        <span
                          class="flex-shrink-0 w-2 h-2 rounded-full bg-n-brand"
                        />
                        <span class="font-medium text-n-slate-12">
                          {{ row.value }}
                        </span>
                      </div>
                    </td>

                    <td
                      class="py-3 px-4 text-right tabular-nums text-n-slate-12"
                    >
                      {{ row.customers }}
                    </td>

                    <td
                      class="py-3 px-4 text-right tabular-nums text-n-slate-10"
                    >
                      {{ row.customers_pct }}%
                    </td>

                    <td
                      class="py-3 px-4 text-right tabular-nums text-n-slate-12"
                    >
                      {{ row.bookings }}
                    </td>

                    <td
                      class="py-3 px-4 text-right tabular-nums text-n-slate-10"
                    >
                      {{ row.bookings_pct }}%
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div
            v-if="!rows.length"
            class="flex flex-col items-center justify-center gap-2 py-16 text-n-slate-9"
          >
            <Icon icon="i-lucide-inbox" class="text-xl" />
            <p class="text-xs">{{ $t('ATTRIBUTION_REPORTS.EMPTY') }}</p>
          </div>
        </template>
      </div>
    </main>

    <footer class="sticky bottom-0 z-0 bg-n-surface-1">
      <PaginationFooter
        v-model:current-page="currentPage"
        :total-items="rows.length"
        :items-per-page="PAGE_SIZE"
      />
    </footer>
  </div>
</template>
