<script>
import BookingPlatformReports from './components/BookingPlatformReports.vue';
import { useAlert, useTrack } from 'dashboard/composables';
import ReportFilters from './components/ReportFilters.vue';
import { GROUP_BY_FILTER } from './constants';
import { REPORTS_EVENTS } from '../../../../helper/AnalyticsHelper/events';
import ReportContainer from './ReportContainer.vue';
import ReportHeader from './components/ReportHeader.vue';

const REPORTS_KEYS = {
  LINKS_SENT: 'handoff_links_sent',
  FORMS_COMPLETED: 'handoff_forms_completed',
};

export default {
  name: 'HandoffReports',
  components: {
    BookingPlatformReports,
    ReportHeader,
    ReportFilters,
    ReportContainer,
  },
  data() {
    return {
      from: 0,
      to: 0,
      groupBy: GROUP_BY_FILTER[1],
      businessHours: false,
    };
  },
  methods: {
    fetchAllData() {
      this.fetchHandoffSummary();
      this.fetchChartData();
    },
    fetchHandoffSummary() {
      try {
        this.$store.dispatch('fetchHandoffSummary', this.getRequestPayload());
      } catch {
        useAlert(this.$t('REPORT.SUMMARY_FETCHING_FAILED'));
      }
    },
    async fetchChartData() {
      const payload = this.getRequestPayload();

      try {
        // Fetch both metrics - the store will make only 1 API call for both
        await Promise.all([
          this.$store.dispatch('fetchAccountReport', {
            metric: REPORTS_KEYS.LINKS_SENT,
            ...payload,
          }),
          this.$store.dispatch('fetchAccountReport', {
            metric: REPORTS_KEYS.FORMS_COMPLETED,
            ...payload,
          }),
        ]);
      } catch {
        useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
      }
    },
    getRequestPayload() {
      return {
        from: this.from,
        to: this.to,
        groupBy: this.groupBy?.period,
        businessHours: this.businessHours,
      };
    },
    onFilterChange({ from, to, groupBy, businessHours }) {
      this.from = from;
      this.to = to;
      this.groupBy = groupBy;
      this.businessHours = businessHours;
      this.fetchAllData();

      useTrack(REPORTS_EVENTS.FILTER_REPORT, {
        filterValue: { from, to, groupBy, businessHours },
        reportType: 'handoff',
      });
    },
  },
};
</script>

<template>
  <ReportHeader :header-title="$t('HANDOFF_REPORTS.HEADER')" />
  <div class="flex flex-col gap-3">
    <ReportFilters
      :show-entity-filter="false"
      :show-business-hours="false"
      show-group-by
      @filter-change="onFilterChange"
    />
    <section>
      <h3 class="mb-2 text-sm font-semibold text-n-slate-12">
        {{ $t('BOOKING_PLATFORM_REPORTS.ALL_PLATFORMS') }}
      </h3>
      <ReportContainer
        :group-by="groupBy"
        :report-keys="{
          LINKS_SENT: 'handoff_links_sent',
          FORMS_COMPLETED: 'handoff_forms_completed',
        }"
        :subtitles="{
          LINKS_SENT: $t('HANDOFF_REPORTS.INFO.LINKS_SENT'),
          FORMS_COMPLETED: $t('HANDOFF_REPORTS.INFO.FORMS_COMPLETED'),
        }"
        account-summary-key="getHandoffSummary"
        summary-fetching-key="getHandoffSummaryFetchingStatus"
      />
    </section>
    <BookingPlatformReports
      type="handoff"
      :group-by="groupBy"
      account-summary-key="getHandoffSummary"
      summary-fetching-key="getHandoffSummaryFetchingStatus"
    />
  </div>
</template>
