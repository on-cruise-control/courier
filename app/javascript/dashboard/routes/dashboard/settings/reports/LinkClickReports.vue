<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import format from 'date-fns/format';
import fromUnixTime from 'date-fns/fromUnixTime';
import parseISO from 'date-fns/parseISO';
import { useAlert } from 'dashboard/composables';
import ReportsAPI from 'dashboard/api/reports';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import LineChart from 'shared/components/charts/CustomLineChart.vue';
import ReportFilters from './components/ReportFilters.vue';
import ReportHeader from './components/ReportHeader.vue';
import { GROUP_BY_FILTER, getMetricChart } from './constants';

const { t } = useI18n();

// The dealership API has no yearly bucket, so yearly grouping falls back to monthly.
const API_PERIODS = {
  day: 'daily',
  week: 'weekly',
  month: 'monthly',
  year: 'monthly',
};

const groupBy = ref(GROUP_BY_FILTER[1]);
const clicks = ref([]);
const total = ref(0);
const isFetching = ref(false);

const metricChart = getMetricChart('link_clicks');

const isDarkMode = ref(document.body.classList.contains('dark'));
let darkObserver;
onMounted(() => {
  darkObserver = new MutationObserver(() => {
    isDarkMode.value = document.body.classList.contains('dark');
  });
  darkObserver.observe(document.body, {
    attributes: true,
    attributeFilter: ['class'],
  });
});
onBeforeUnmount(() => darkObserver?.disconnect());

const lineColor = computed(() =>
  isDarkMode.value ? 'rgb(69, 118, 147)' : 'rgb(24, 41, 51)'
);
const fillColor = computed(() =>
  isDarkMode.value ? 'rgba(56, 200, 232, 0.15)' : 'rgba(24, 41, 51, 0.1)'
);

// Each bucket is keyed by its period (date, week, month); weekly and monthly labels arrive pre-formatted.
const bucketLabel = ({ count, ...bucket }) => {
  const [label] = Object.values(bucket);
  return groupBy.value.period === 'day'
    ? format(parseISO(label), 'dd-MMM')
    : label;
};

const collection = computed(() => ({
  labels: clicks.value.map(bucketLabel),
  datasets: [
    {
      type: 'line',
      fill: true,
      backgroundColor: fillColor.value,
      borderColor: lineColor.value,
      pointBackgroundColor: lineColor.value,
      pointRadius: 4,
      pointHoverRadius: 6,
      tension: 0.3,
      yAxisID: 'y',
      label: t('LINK_CLICK_REPORTS.METRIC_NAME'),
      data: clicks.value.map(item => item.count),
    },
  ],
}));

const chartOptions = {
  scales: {
    ...metricChart.scales,
    y: {
      ...metricChart.scales.y,
      min: 0,
      ticks: { ...metricChart.scales.y.ticks, beginAtZero: true },
    },
  },
};

const onFilterChange = async ({ from, to, groupBy: selectedGroupBy }) => {
  groupBy.value = selectedGroupBy;
  isFetching.value = true;
  try {
    const { data } = await ReportsAPI.getLinkClicks({
      fromDate: format(fromUnixTime(from), 'yyyy-MM-dd'),
      toDate: format(fromUnixTime(to), 'yyyy-MM-dd'),
      period: API_PERIODS[selectedGroupBy.period],
    });
    clicks.value = data.data || [];
    total.value = data.total || 0;
  } catch {
    useAlert(t('LINK_CLICK_REPORTS.FETCHING_FAILED'));
  } finally {
    isFetching.value = false;
  }
};
</script>

<template>
  <ReportHeader :header-title="$t('LINK_CLICK_REPORTS.HEADER')" />
  <div class="flex flex-col gap-3">
    <ReportFilters
      :show-entity-filter="false"
      :show-business-hours="false"
      show-group-by
      @filter-change="onFilterChange"
    />
    <div
      class="px-6 py-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 mt-4"
    >
      <div class="p-4 mb-3 rounded-md text-n-slate-11">
        <span class="text-sm">{{ $t('LINK_CLICK_REPORTS.METRIC_NAME') }}</span>
        <div class="text-n-slate-12">
          <Spinner v-if="isFetching" />
          <span v-else class="text-xl font-semibold">{{ total }}</span>
        </div>
        <div class="mt-4 h-72">
          <woot-loading-state
            v-if="isFetching"
            class="text-xs"
            :message="$t('REPORT.LOADING_CHART')"
          />
          <div v-else class="flex items-center justify-center h-72">
            <LineChart
              v-if="clicks.length"
              :collection="collection"
              :chart-options="chartOptions"
            />
            <span v-else class="text-sm text-n-slate-10">
              {{ $t('REPORT.NO_ENOUGH_DATA') }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
