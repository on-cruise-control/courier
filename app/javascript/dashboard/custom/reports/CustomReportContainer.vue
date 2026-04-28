<script>
import { mapGetters } from 'vuex';
import { useReportMetrics } from 'dashboard/composables/useReportMetrics';
import { GROUP_BY_FILTER, METRIC_CHART } from 'dashboard/routes/dashboard/settings/reports/constants';
import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';
import { formatTime } from '@chatwoot/utils';
import ChartStats from 'dashboard/routes/dashboard/settings/reports/components/ChartElements/ChartStats.vue';
import LineChart from 'shared/components/charts/CustomLineChart.vue';

export default {
  components: { ChartStats, LineChart },
  props: {
    groupBy: {
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
    reportKeys: {
      type: Object,
      default: () => ({
        CONVERSATIONS: 'conversations_count',
        INCOMING_MESSAGES: 'incoming_messages_count',
        OUTGOING_MESSAGES: 'outgoing_messages_count',
        FIRST_RESPONSE_TIME: 'avg_first_response_time',
        RESOLUTION_TIME: 'avg_resolution_time',
        RESOLUTION_COUNT: 'resolutions_count',
        REPLY_TIME: 'reply_time',
      }),
    },
  },
  setup(props) {
    const { calculateTrend, isAverageMetricType } = useReportMetrics(
      props.accountSummaryKey
    );
    return { calculateTrend, isAverageMetricType };
  },
  data() {
    return {
      isDarkMode: document.documentElement.classList.contains('dark'),
    };
  },
  mounted() {
    this._darkObserver = new MutationObserver(() => {
      this.isDarkMode = document.documentElement.classList.contains('dark');
    });
    this._darkObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class'],
    });
  },
  beforeUnmount() {
    this._darkObserver?.disconnect();
  },
  computed: {
    ...mapGetters({
      accountReport: 'getAccountReports',
    }),
    chartLineColor() {
      return this.isDarkMode ? 'rgb(56, 200, 232)' : 'rgb(24, 41, 51)';
    },
    chartFillColor() {
      return this.isDarkMode ? 'rgba(56, 200, 232, 0.15)' : 'rgba(24, 41, 51, 0.1)';
    },
    metrics() {
      const reportKeys = Object.keys(this.reportKeys);
      const infoText = {
        FIRST_RESPONSE_TIME: this.$t(
          `REPORT.METRICS.FIRST_RESPONSE_TIME.INFO_TEXT`
        ),
        RESOLUTION_TIME: this.$t(`REPORT.METRICS.RESOLUTION_TIME.INFO_TEXT`),
      };
      return reportKeys.map(key => ({
        NAME: this.$t(`REPORT.METRICS.${key}.NAME`),
        KEY: this.reportKeys[key],
        DESC: this.$t(`REPORT.METRICS.${key}.DESC`),
        INFO_TEXT: infoText[key],
        TOOLTIP_TEXT: `REPORT.METRICS.${key}.TOOLTIP_TEXT`,
        trend: this.calculateTrend(this.reportKeys[key]),
      }));
    },
  },
  methods: {
    getCollection(metric) {
      if (!this.accountReport.data[metric.KEY]) {
        return {};
      }
      const data = this.accountReport.data[metric.KEY];
      const labels = data.map(element => {
        if (this.groupBy?.period === GROUP_BY_FILTER[2].period) {
          let week_date = new Date(fromUnixTime(element.timestamp));
          const first_day = week_date.getDate() - week_date.getDay();
          const last_day = first_day + 6;
          const week_first_date = new Date(week_date.setDate(first_day));
          const week_last_date = new Date(week_date.setDate(last_day));
          return `${format(week_first_date, 'dd-MMM')} - ${format(
            week_last_date,
            'dd-MMM'
          )}`;
        }
        if (this.groupBy?.period === GROUP_BY_FILTER[3].period) {
          return format(fromUnixTime(element.timestamp), 'MMM-yyyy');
        }
        if (this.groupBy?.period === GROUP_BY_FILTER[4].period) {
          return format(fromUnixTime(element.timestamp), 'yyyy');
        }
        return format(fromUnixTime(element.timestamp), 'dd-MMM');
      });

      // Convert all datasets to line type
      const datasets = METRIC_CHART[metric.KEY].datasets.map(dataset => {
        return {
          type: 'line',
          fill: true,
          backgroundColor: this.chartFillColor,
          borderColor: this.chartLineColor,
          pointBackgroundColor: this.chartLineColor,
          pointRadius: 4,
          pointHoverRadius: 6,
          tension: 0.3,
          yAxisID: 'y',
          label: metric.NAME,
          data: data.map(element =>
            dataset.type === 'line' ? element.count : element.value
          ),
        };
      });

      return {
        labels,
        datasets,
      };
    },
    getChartOptions(metric) {
      const baseScales = METRIC_CHART[metric.KEY].scales;
      const options = {
        scales: {
          ...baseScales,
          y: {
            ...baseScales.y,
            min: 0,
            ticks: {
              ...baseScales.y?.ticks,
              beginAtZero: true,
            },
          },
        },
      };

      // Only add tooltip configuration for time-based metrics
      if (this.isAverageMetricType(metric.KEY)) {
        options.plugins = {
          tooltip: {
            callbacks: {
              label: ({ raw, dataIndex }) => {
                return this.$t(metric.TOOLTIP_TEXT, {
                  metricValue: formatTime(raw || 0),
                  conversationCount:
                    this.accountReport.data[metric.KEY][dataIndex]?.count || 0,
                });
              },
            },
          },
        };
      }

      return options;
    },
  },
};
</script>

<template>
  <div
    class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-2 px-6 py-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <div
      v-for="metric in metrics"
      :key="metric.KEY"
      class="p-4 mb-3 rounded-md"
    >
      <ChartStats
        :metric="metric"
        :account-summary-key="accountSummaryKey"
        :summary-fetching-key="summaryFetchingKey"
      />
      <div class="mt-4 h-72">
        <woot-loading-state
          v-if="accountReport.isFetching[metric.KEY]"
          class="text-xs"
          :message="$t('REPORT.LOADING_CHART')"
        />
        <div v-else class="flex items-center justify-center h-72">
          <LineChart
            v-if="accountReport.data[metric.KEY].length"
            :collection="getCollection(metric)"
            :chart-options="getChartOptions(metric)"
          />
          <span v-else class="text-sm text-n-slate-10">
            {{ $t('REPORT.NO_ENOUGH_DATA') }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
