<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { vOnClickOutside } from '@vueuse/components';
import { useStore, useMapGetter } from 'dashboard/composables/store.js';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import format from 'date-fns/format';
import WootDateRangePicker from 'dashboard/components/ui/DateRangePicker.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ReportHeader from './components/ReportHeader.vue';
import { ATTRIBUTION_DIMENSIONS as DIMENSIONS } from './attributionDimensions';
import { useAttributionFilterQuery } from './useAttributionFilterQuery';
import { attributionNavState } from './attributionNavigationState';

let conditionUid = 0;
const nextConditionId = () => {
  conditionUid += 1;
  return conditionUid;
};

const store = useStore();
const { t } = useI18n();
const route = useRoute();
const { accountScopedRoute } = useAccount();

// Applied filters live in the URL query string, so they survive both a
const {
  dateRange,
  selectedFilters,
  buildFilterPayload,
  setFiltersQuery,
  DEFAULT_DATE_RANGE,
  DEFAULT_FILTERS,
} = useAttributionFilterQuery();

// Pending state (edited inside the panel, only applied on submit).
const isFilterPanelOpen = ref(false);
const pendingDateRange = ref(DEFAULT_DATE_RANGE());
// Each condition: { id, attributeKey, value }
const pendingConditions = ref([]);

const filterValues = useMapGetter('getAttributionValues');
const report = useMapGetter('getAttributionReport');
const isFetchingReport = useMapGetter('isFetchingAttributionReport');

const totals = computed(() => report.value?.totals || {});
const breakdown = computed(() => report.value?.breakdown || {});

const valueCountFor = dimensionKey =>
  (breakdown.value[dimensionKey] || []).length;

const activeFilterCount = computed(
  () =>
    Object.values(selectedFilters.value).filter(value => value !== '').length
);
const hasActiveFilters = computed(() => activeFilterCount.value > 0);
const canAddCondition = computed(
  () => pendingConditions.value.length < DIMENSIONS.length
);

const attributeOptionsFor = currentKey => {
  const usedKeys = pendingConditions.value.map(c => c.attributeKey);
  return DIMENSIONS.filter(
    dimension =>
      dimension.key === currentKey || !usedKeys.includes(dimension.key)
  ).map(dimension => ({
    value: dimension.key,
    label: t(`ATTRIBUTION_REPORTS.DIMENSIONS.${dimension.i18nKey}`),
  }));
};

const valueOptionsFor = attributeKey => {
  const values = filterValues.value?.[attributeKey] || [];
  return values.map(value => ({ value, label: value }));
};

const addCondition = () => {
  const usedKeys = pendingConditions.value.map(c => c.attributeKey);
  const nextDimension = DIMENSIONS.find(d => !usedKeys.includes(d.key));
  if (!nextDimension) return;

  pendingConditions.value.push({
    id: nextConditionId(),
    attributeKey: nextDimension.key,
    value: valueOptionsFor(nextDimension.key)[0]?.value || '',
  });
};

const removeCondition = index => {
  pendingConditions.value.splice(index, 1);
};

const onConditionAttributeChange = condition => {
  condition.value = valueOptionsFor(condition.attributeKey)[0]?.value || '';
};

const fetchReport = async ({ force = false } = {}) => {
  try {
    await store.dispatch('fetchAttributionReport', {
      ...buildFilterPayload(),
      force,
    });
  } catch {
    useAlert(t('ATTRIBUTION_REPORTS.FETCHING_FAILED'));
  }
};

const conditionsFromSelectedFilters = () =>
  DIMENSIONS.filter(
    dimension => selectedFilters.value[dimension.filterKey]
  ).map(dimension => ({
    id: nextConditionId(),
    attributeKey: dimension.key,
    value: selectedFilters.value[dimension.filterKey],
  }));

const defaultCondition = () => {
  const dimension = DIMENSIONS[0];
  return {
    id: nextConditionId(),
    attributeKey: dimension.key,
    value: valueOptionsFor(dimension.key)[0]?.value || '',
  };
};

const openFilterPanel = () => {
  pendingDateRange.value = [...dateRange.value];
  const conditions = conditionsFromSelectedFilters();
  pendingConditions.value = conditions.length
    ? conditions
    : [defaultCondition()];
  isFilterPanelOpen.value = true;
};

const toggleFilterPanel = () => {
  if (isFilterPanelOpen.value) {
    isFilterPanelOpen.value = false;
  } else {
    openFilterPanel();
  }
};

const closeFilterPanel = () => {
  isFilterPanelOpen.value = false;
};

const onPendingDateRangeChange = value => {
  pendingDateRange.value = value;
};

const applyFilters = async () => {
  const nextFilters = DEFAULT_FILTERS();
  pendingConditions.value.forEach(condition => {
    const dimension = DIMENSIONS.find(d => d.key === condition.attributeKey);
    if (dimension && condition.value) {
      nextFilters[dimension.filterKey] = condition.value;
    }
  });

  await setFiltersQuery(pendingDateRange.value, nextFilters);
  isFilterPanelOpen.value = false;
  fetchReport();
};

const clearFilters = async () => {
  pendingDateRange.value = DEFAULT_DATE_RANGE();
  pendingConditions.value = [];

  await setFiltersQuery(DEFAULT_DATE_RANGE(), DEFAULT_FILTERS());
  isFilterPanelOpen.value = false;
  fetchReport();
};

onMounted(() => {
  store.dispatch('fetchAttributionValues');
  // Force a fresh fetch when entering the report normally (e.g. from the
  // sidebar), but not when navigating back here from the detail page — that
  // should just reuse whatever's already cached.
  const shouldForce = !attributionNavState.skipNextForceFetch;
  attributionNavState.skipNextForceFetch = false;
  fetchReport({ force: shouldForce });
});
</script>

<template>
  <ReportHeader :header-title="$t('ATTRIBUTION_REPORTS.HEADER')" />
  <div class="flex flex-col gap-5 pb-10">
    <!-- Filters -->
    <div class="flex items-center gap-2 flex-wrap">
      <div class="relative">
        <Button
          id="toggleAttributionFilterButton"
          icon="i-lucide-list-filter"
          slate
          faded
          size="sm"
          @click="toggleFilterPanel"
        >
          {{ $t('ATTRIBUTION_REPORTS.FILTERS.LABEL') }}
          <span
            v-if="hasActiveFilters"
            class="inline-flex items-center justify-center min-w-4 h-4 px-1 rounded-full bg-n-brand text-white text-[10px] font-semibold"
          >
            {{ activeFilterCount }}
          </span>
        </Button>

        <div
          v-if="isFilterPanelOpen"
          v-on-click-outside="[
            closeFilterPanel,
            {
              ignore: ['#toggleAttributionFilterButton', '.mx-datepicker-main'],
            },
          ]"
          class="absolute z-40 mt-2 w-[calc(100vw-2rem)] sm:w-[480px] overflow-visible border border-n-gray-4 bg-n-solid-1 dark:bg-n-solid-2 shadow-lg rounded-xl p-4 grid gap-4 max-[484px]:fixed max-[484px]:inset-x-6 max-[484px]:top-24 max-[484px]:mt-0 max-[484px]:w-auto max-[484px]:max-h-[calc(100vh-7rem)] max-[484px]:overflow-y-auto"
        >
          <h3 class="text-sm font-medium leading-6 text-n-slate-12">
            {{ $t('ATTRIBUTION_REPORTS.FILTERS.TITLE') }}
          </h3>

          <div
            class="flex items-center gap-3 max-[484px]:flex-col max-[484px]:items-stretch max-[484px]:gap-1.5"
          >
            <span
              class="w-20 flex-shrink-0 text-sm text-n-slate-11 max-[484px]:w-auto"
            >
              {{ $t('ATTRIBUTION_REPORTS.FILTERS.DATE_RANGE') }}
            </span>
            <WootDateRangePicker
              show-range
              class="no-margin auto-width flex-1 min-w-0"
              :value="pendingDateRange"
              :confirm-text="$t('REPORT.CUSTOM_DATE_RANGE.CONFIRM')"
              :placeholder="$t('REPORT.CUSTOM_DATE_RANGE.PLACEHOLDER')"
              @change="onPendingDateRangeChange"
            />
          </div>

          <div
            v-if="pendingConditions.length"
            class="flex flex-col gap-3 pt-3 border-t border-n-weak"
          >
            <div
              v-for="(condition, index) in pendingConditions"
              :key="condition.id"
              class="flex items-center gap-2 max-[484px]:flex-wrap"
            >
              <Select
                v-model="condition.attributeKey"
                class="w-32 flex-shrink-0 max-[484px]:w-full"
                :options="attributeOptionsFor(condition.attributeKey)"
                @update:model-value="onConditionAttributeChange(condition)"
              />
              <span
                class="flex-shrink-0 text-xs text-n-slate-10 max-[484px]:hidden"
              >
                {{ $t('ATTRIBUTION_REPORTS.FILTERS.EQUAL_TO') }}
              </span>
              <Select
                v-model="condition.value"
                class="flex-1 min-w-0"
                :options="valueOptionsFor(condition.attributeKey)"
              />
              <Button
                icon="i-lucide-trash-2"
                ghost
                slate
                size="sm"
                class="flex-shrink-0"
                @click="removeCondition(index)"
              />
            </div>
          </div>

          <div class="pt-1">
            <Button
              v-if="canAddCondition"
              link
              blue
              size="sm"
              icon="i-lucide-plus"
              @click="addCondition"
            >
              {{ $t('ATTRIBUTION_REPORTS.FILTERS.ADD_FILTER') }}
            </Button>
          </div>

          <div
            class="flex gap-2 justify-end pt-3 border-t border-n-weak max-[484px]:flex-col max-[484px]:items-stretch max-[484px]:justify-start"
          >
            <Button sm faded slate @click="clearFilters">
              {{ $t('ATTRIBUTION_REPORTS.FILTERS.CLEAR') }}
            </Button>
            <Button sm solid blue @click="applyFilters">
              {{ $t('ATTRIBUTION_REPORTS.FILTERS.APPLY') }}
            </Button>
          </div>
        </div>
      </div>

      <span class="text-xs text-n-slate-10">
        {{ format(dateRange[0], 'MMM d, yyyy') }} –
        {{ format(dateRange[1], 'MMM d, yyyy') }}
      </span>
    </div>

    <!-- Totals -->
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <div
        class="flex items-center gap-4 p-4 rounded-xl border border-n-weak shadow-sm bg-n-solid-1 dark:bg-n-solid-2"
      >
        <span
          class="flex-shrink-0 flex items-center justify-center w-11 h-11 rounded-xl bg-n-blue-9 text-white shadow-sm"
        >
          <Icon icon="i-lucide-users" class="text-xl" />
        </span>
        <div class="flex flex-col">
          <span
            class="text-xs font-semibold uppercase tracking-wider text-n-slate-10"
          >
            {{ $t('ATTRIBUTION_REPORTS.TOTALS.CUSTOMERS') }}
          </span>
          <Spinner v-if="isFetchingReport" class="mt-1" />
          <span v-else class="text-2xl font-bold tabular-nums text-n-slate-12">
            {{ totals.customers || 0 }}
          </span>
        </div>
      </div>
      <div
        class="flex items-center gap-4 p-4 rounded-xl border border-n-weak shadow-sm bg-n-solid-1 dark:bg-n-solid-2"
      >
        <span
          class="flex-shrink-0 flex items-center justify-center w-11 h-11 rounded-xl bg-n-teal-9 text-white shadow-sm"
        >
          <Icon icon="i-lucide-calendar-check" class="text-xl" />
        </span>
        <div class="flex flex-col">
          <span
            class="text-xs font-semibold uppercase tracking-wider text-n-slate-10"
          >
            {{ $t('ATTRIBUTION_REPORTS.TOTALS.BOOKINGS') }}
          </span>
          <Spinner v-if="isFetchingReport" class="mt-1" />
          <span v-else class="text-2xl font-bold tabular-nums text-n-slate-12">
            {{ totals.bookings || 0 }}
          </span>
        </div>
      </div>
    </div>

    <!-- Attribution parameters -->
    <div v-if="isFetchingReport" class="flex items-center justify-center p-16">
      <Spinner />
    </div>
    <div v-else class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
      <router-link
        v-for="dimension in DIMENSIONS"
        :key="dimension.key"
        :to="
          accountScopedRoute(
            'attribution_report_detail',
            { dimension: dimension.key },
            route.query
          )
        "
        class="flex flex-col gap-3 p-4 rounded-xl border border-n-weak shadow-sm bg-n-solid-1 dark:bg-n-solid-2 hover:border-n-brand hover:shadow-md transition-all"
      >
        <span
          class="flex items-center gap-2 text-sm font-semibold text-n-slate-12"
        >
          <Icon :icon="dimension.icon" class="text-base text-n-slate-10" />
          {{ $t(`ATTRIBUTION_REPORTS.DIMENSIONS.${dimension.i18nKey}`) }}
        </span>
        <span class="text-xs text-n-slate-10">
          {{
            $t('ATTRIBUTION_REPORTS.OVERVIEW.VALUE_COUNT', {
              n: valueCountFor(dimension.key),
            })
          }}
        </span>
        <div class="flex items-center gap-4 pt-2 border-t border-n-weak">
          <span class="flex items-center gap-1.5 text-xs text-n-slate-11">
            <Icon icon="i-lucide-users" class="text-sm text-n-slate-9" />
            <span class="font-medium tabular-nums">{{
              totals.customers || 0
            }}</span>
            {{ $t('ATTRIBUTION_REPORTS.OVERVIEW.CUSTOMERS') }}
          </span>
          <span class="flex items-center gap-1.5 text-xs text-n-slate-11">
            <Icon
              icon="i-lucide-calendar-check"
              class="text-sm text-n-slate-9"
            />
            <span class="font-medium tabular-nums">{{
              totals.bookings || 0
            }}</span>
            {{ $t('ATTRIBUTION_REPORTS.OVERVIEW.BOOKINGS') }}
          </span>
        </div>
      </router-link>
    </div>
  </div>
</template>
