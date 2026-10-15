<script setup>
import { useReportMetrics } from 'dashboard/composables/useReportMetrics';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { STATUS } from 'dashboard/store/constants';
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';

const props = defineProps({
  metric: {
    type: Object,
    default: () => ({}),
  },
  accountSummaryKey: {
    type: String,
    default: 'getAccountSummary',
  },
  summaryFetchingKey: {
    type: String,
    default: 'getAccountSummaryFetchingStatus',
  },
});

const { t } = useI18n();

const isInfoOpen = ref(false);

const { calculateTrend, displayMetric, isAverageMetricType, fetchingStatus } =
  useReportMetrics(props.accountSummaryKey, props.summaryFetchingKey);

const trendColor = (value, key) => {
  if (isAverageMetricType(key)) {
    return value > 0
      ? 'border-n-ruby-9 text-n-ruby-9'
      : 'border-n-teal-10 text-n-teal-10';
  }
  return value < 0
    ? 'border-n-ruby-9 text-n-ruby-9'
    : 'border-n-teal-10 text-n-teal-10';
};
</script>

<template>
  <div class="text-n-slate-11">
    <div class="flex items-center">
      <span class="text-sm">
        {{ metric.NAME }}
      </span>
      <div
        v-if="metric.SUBTITLE"
        v-on-click-outside="() => (isInfoOpen = false)"
        class="relative flex items-center"
        @mouseenter="isInfoOpen = true"
        @mouseleave="isInfoOpen = false"
      >
        <button
          type="button"
          class="flex items-center text-n-slate-10 hover:text-n-slate-12"
          :aria-label="metric.SUBTITLE"
          @click="isInfoOpen = true"
        >
          <Icon icon="i-lucide-info" class="size-3.5" />
        </button>
        <p
          v-if="isInfoOpen"
          class="absolute top-full left-0 z-20 w-56 p-2 mt-1 text-xs rounded-lg shadow-lg outline outline-1 outline-n-container bg-n-solid-3 text-n-slate-12"
        >
          {{ metric.SUBTITLE }}
        </p>
      </div>
    </div>
    <div class="flex items-end text-n-slate-12">
      <div v-if="fetchingStatus === STATUS.FETCHING">
        <Spinner />
      </div>
      <div
        v-else-if="fetchingStatus === STATUS.FAILED"
        class="text-n-ruby-10 text-sm"
      >
        {{ t('REPORT.SUMMARY_FETCHING_FAILED') }}
      </div>
      <div
        v-else-if="fetchingStatus === STATUS.FINISHED"
        class="text-xl font-medium"
      >
        {{ displayMetric(metric.KEY) }}
      </div>
      <div
        v-if="metric.trend && fetchingStatus === STATUS.FINISHED"
        class="text-xs ml-4 flex items-center mb-0.5"
      >
        <div
          v-if="metric.trend < 0"
          class="h-0 w-0 border-x-4 medium border-x-transparent border-t-[8px] mr-1"
          :class="trendColor(metric.trend, metric.KEY)"
        />
        <div
          v-else
          class="h-0 w-0 border-x-4 medium border-x-transparent border-b-[8px] mr-1"
          :class="trendColor(metric.trend, metric.KEY)"
        />
        <span class="font-medium" :class="trendColor(metric.trend, metric.KEY)">
          {{ calculateTrend(metric.KEY) }}%
        </span>
      </div>
    </div>
  </div>
</template>
