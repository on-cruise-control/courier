<script>
import V4Button from 'dashboard/components-next/button/Button.vue';
import { useAlert, useTrack } from 'dashboard/composables';
import ReportFilters from 'dashboard/routes/dashboard/settings/reports/components/ReportFilters.vue';
import { GROUP_BY_FILTER } from 'dashboard/routes/dashboard/settings/reports/constants';
import { REPORTS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import { generateFileName } from 'dashboard/helper/downloadHelper';
import CustomReportContainer from './CustomReportContainer.vue';
import ReportHeader from 'dashboard/routes/dashboard/settings/reports/components/ReportHeader.vue';

const REPORTS_KEYS = {
  CONVERSATIONS: 'conversations_count',
  INCOMING_MESSAGES: 'incoming_messages_count',
  OUTGOING_MESSAGES: 'outgoing_messages_count',
  FIRST_RESPONSE_TIME: 'avg_first_response_time',
  RESOLUTION_TIME: 'avg_resolution_time',
  RESOLUTION_COUNT: 'resolutions_count',
  REPLY_TIME: 'reply_time',
};

export default {
  name: 'CustomConversationReports',
  components: {
    ReportHeader,
    ReportFilters,
    CustomReportContainer,
    V4Button,
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
      this.fetchAccountSummary();
      this.fetchChartData();
    },
    fetchAccountSummary() {
      try {
        this.$store.dispatch('fetchAccountSummary', this.getRequestPayload());
      } catch {
        useAlert(this.$t('REPORT.SUMMARY_FETCHING_FAILED'));
      }
    },
    fetchChartData() {
      [
        'CONVERSATIONS',
        'INCOMING_MESSAGES',
        'OUTGOING_MESSAGES',
        'FIRST_RESPONSE_TIME',
        'RESOLUTION_TIME',
        'RESOLUTION_COUNT',
        'REPLY_TIME',
      ].forEach(async key => {
        try {
          await this.$store.dispatch('fetchAccountReport', {
            metric: REPORTS_KEYS[key],
            ...this.getRequestPayload(),
          });
        } catch {
          useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
        }
      });
    },
    getRequestPayload() {
      const { from, to, groupBy, businessHours } = this;

      return {
        from,
        to,
        groupBy: groupBy?.period,
        businessHours,
      };
    },
    downloadAgentReports() {
      const { from, to } = this;
      const fileName = generateFileName({
        type: 'agent',
        to,
        businessHours: this.businessHours,
      });
      this.$store.dispatch('downloadAgentReports', {
        from,
        to,
        fileName,
        businessHours: this.businessHours,
      });
    },
    onFilterChange({ from, to, groupBy, businessHours }) {
      this.from = from;
      this.to = to;
      this.groupBy = groupBy;
      this.businessHours = businessHours;
      this.fetchAllData();

      useTrack(REPORTS_EVENTS.FILTER_REPORT, {
        filterValue: { from, to, groupBy, businessHours },
        reportType: 'conversations',
      });
    },
  },
};
</script>

<template>
  <ReportHeader :header-title="$t('REPORT.HEADER')">
    <V4Button
      :label="$t('AGENT_REPORTS.DOWNLOAD_AGENT_REPORTS')"
      icon="i-ph-download-simple"
      size="sm"
      @click="downloadAgentReports"
    />
  </ReportHeader>
  <div class="flex flex-col gap-3">
    <ReportFilters
      :show-entity-filter="false"
      show-group-by
      @filter-change="onFilterChange"
    />
    <CustomReportContainer :group-by="groupBy" />
  </div>
</template>
