/* eslint no-console: 0 */
import * as types from '../mutation-types';
import { STATUS } from '../constants';
import Report from '../../api/reports';
import { downloadCsvFile, generateFileName } from '../../helper/downloadHelper';
import AnalyticsHelper from '../../helper/AnalyticsHelper';
import { REPORTS_EVENTS } from '../../helper/AnalyticsHelper/events';
import { clampDataBetweenTimeline } from 'shared/helpers/ReportsDataHelper';
import liveReports from '../../api/liveReports';
import { BOOKING_STATS_METRICS } from 'dashboard/routes/dashboard/settings/reports/constants';

const state = {
  fetchingStatus: false,
  accountSummaryFetchingStatus: STATUS.FINISHED,
  botSummaryFetchingStatus: STATUS.FINISHED,
  accountReport: {
    isFetching: {
      conversations_count: false,
      incoming_messages_count: false,
      outgoing_messages_count: false,
      avg_first_response_time: false,
      avg_resolution_time: false,
      resolutions_count: false,
      bot_resolutions_count: false,
      bot_handoffs_count: false,
      reply_time: false,
      ...Object.fromEntries(
        BOOKING_STATS_METRICS.map(metric => [metric, false])
      ),
    },
    data: {
      conversations_count: [],
      incoming_messages_count: [],
      outgoing_messages_count: [],
      avg_first_response_time: [],
      avg_resolution_time: [],
      resolutions_count: [],
      bot_resolutions_count: [],
      bot_handoffs_count: [],
      reply_time: [],
      ...Object.fromEntries(BOOKING_STATS_METRICS.map(metric => [metric, []])),
    },
  },
  // Cache for booking stats to avoid duplicate API calls
  bookingStatsCache: {
    data: null,
    params: null,
    timestamp: null,
  },
  accountSummary: {
    avg_first_response_time: 0,
    avg_resolution_time: 0,
    conversations_count: 0,
    incoming_messages_count: 0,
    outgoing_messages_count: 0,
    reply_time: 0,
    resolutions_count: 0,
    bot_resolutions_count: 0,
    bot_handoffs_count: 0,
    previous: {},
  },
  botSummary: {
    bot_resolutions_count: 0,
    bot_handoffs_count: 0,
    previous: {},
  },
  bookingSummary: {
    booking_links_sent: 0,
    booking_forms_completed: 0,
    previous: {},
  },
  handoffSummary: {
    handoff_links_sent: 0,
    handoff_forms_completed: 0,
    previous: {},
  },
  bookingSummaryFetchingStatus: STATUS.FINISHED,
  handoffSummaryFetchingStatus: STATUS.FINISHED,
  overview: {
    uiFlags: {
      isFetchingAccountConversationMetric: false,
      isFetchingAccountConversationsHeatmap: false,
      isFetchingAccountResolutionsHeatmap: false,
      isFetchingAgentConversationMetric: false,
      isFetchingTeamConversationMetric: false,
    },
    accountConversationMetric: {},
    accountConversationHeatmap: [],
    accountResolutionHeatmap: [],
    agentConversationMetric: [],
    teamConversationMetric: [],
  },
  twilioUsage: {
    data: null,
    isFetching: false,
  },
  walletBalance: {
    data: null,
    isFetching: false,
  },
  attributionValues: {
    data: null,
    isFetching: false,
  },
  attributionReport: {
    data: null,
    params: null,
    isFetching: false,
  },
};

const getters = {
  getAccountReports(_state) {
    return _state.accountReport;
  },
  getAccountSummary(_state) {
    return _state.accountSummary;
  },
  getBotSummary(_state) {
    return _state.botSummary;
  },
  getAccountSummaryFetchingStatus(_state) {
    return _state.accountSummaryFetchingStatus;
  },
  getBotSummaryFetchingStatus(_state) {
    return _state.botSummaryFetchingStatus;
  },
  getBookingSummary(_state) {
    return _state.bookingSummary;
  },
  getBookingSummaryFetchingStatus(_state) {
    return _state.bookingSummaryFetchingStatus;
  },
  getHandoffSummary(_state) {
    return _state.handoffSummary;
  },
  getHandoffSummaryFetchingStatus(_state) {
    return _state.handoffSummaryFetchingStatus;
  },
  getAccountConversationMetric(_state) {
    return _state.overview.accountConversationMetric;
  },
  getAccountConversationHeatmapData(_state) {
    return _state.overview.accountConversationHeatmap;
  },
  getAccountResolutionHeatmapData(_state) {
    return _state.overview.accountResolutionHeatmap;
  },
  getAgentConversationMetric(_state) {
    return _state.overview.agentConversationMetric;
  },
  getTeamConversationMetric(_state) {
    return _state.overview.teamConversationMetric;
  },
  getOverviewUIFlags($state) {
    return $state.overview.uiFlags;
  },
  getTwilioUsage(_state) {
    return _state.twilioUsage.data;
  },
  isFetchingTwilioUsage(_state) {
    return _state.twilioUsage.isFetching;
  },
  getWalletBalance(_state) {
    return _state.walletBalance.data;
  },
  isFetchingWalletBalance(_state) {
    return _state.walletBalance.isFetching;
  },
  getAttributionValues(_state) {
    return _state.attributionValues.data;
  },
  isFetchingAttributionValues(_state) {
    return _state.attributionValues.isFetching;
  },
  getAttributionReport(_state) {
    return _state.attributionReport.data;
  },
  isFetchingAttributionReport(_state) {
    return _state.attributionReport.isFetching;
  },
};

// Every key except timestamp is a metric, including dynamic platform ones like booking_sms_links_sent
const populateBookingStats = (commit, rows) => {
  const metricKeys = new Set(BOOKING_STATS_METRICS);
  rows.forEach(row => Object.keys(row).forEach(key => metricKeys.add(key)));
  metricKeys.delete('timestamp');

  metricKeys.forEach(metricKey => {
    commit(types.default.SET_ACCOUNT_REPORTS, {
      metric: metricKey,
      data: rows.map(row => ({
        timestamp: row.timestamp,
        value: row[metricKey] || 0,
        count: 0,
      })),
    });
    commit(types.default.TOGGLE_ACCOUNT_REPORT_LOADING, {
      metric: metricKey,
      value: false,
    });
  });
};

export const actions = {
  fetchAccountReport({ commit, state: currentState }, reportObj) {
    const { metric } = reportObj;
    commit(types.default.TOGGLE_ACCOUNT_REPORT_LOADING, {
      metric,
      value: true,
    });

    // Use booking stats endpoint for new metrics
    if (BOOKING_STATS_METRICS.includes(metric)) {
      // Check if data already exists (already fetched for any metric)
      const cacheKey = JSON.stringify({
        from: reportObj.from,
        to: reportObj.to,
        groupBy: reportObj.groupBy,
      });
      const cachedKey = currentState.bookingStatsCache.params;
      const isCached =
        cachedKey === cacheKey && currentState.bookingStatsCache.data !== null;

      if (isCached) {
        populateBookingStats(commit, currentState.bookingStatsCache.data);
        return;
      }

      // Make single API call that returns ALL fields (overall and per platform)
      Report.getBookingStats(reportObj)
        .then(response => {
          const rawBreakdownData = response.data;

          // Cache the full breakdown data
          commit(types.default.SET_BOOKING_STATS_CACHE, {
            data: rawBreakdownData,
            params: cacheKey,
            timestamp: Date.now(),
          });

          populateBookingStats(commit, rawBreakdownData);
        })
        .catch(() => {
          // Turn off loading for all metrics
          BOOKING_STATS_METRICS.forEach(metricKey => {
            commit(types.default.TOGGLE_ACCOUNT_REPORT_LOADING, {
              metric: metricKey,
              value: false,
            });
          });
        });
    } else {
      Report.getReports(reportObj).then(accountReport => {
        let { data } = accountReport;
        data = clampDataBetweenTimeline(data, reportObj.from, reportObj.to);
        commit(types.default.SET_ACCOUNT_REPORTS, {
          metric,
          data,
        });
        commit(types.default.TOGGLE_ACCOUNT_REPORT_LOADING, {
          metric,
          value: false,
        });
      });
    }
  },
  fetchAccountConversationHeatmap({ commit }, reportObj) {
    commit(types.default.TOGGLE_HEATMAP_LOADING, true);
    Report.getReports({ ...reportObj, groupBy: 'hour' }).then(heatmapData => {
      let { data } = heatmapData;
      data = clampDataBetweenTimeline(data, reportObj.from, reportObj.to);

      commit(types.default.SET_HEATMAP_DATA, data);
      commit(types.default.TOGGLE_HEATMAP_LOADING, false);
    });
  },
  fetchAccountResolutionHeatmap({ commit }, reportObj) {
    commit(types.default.TOGGLE_RESOLUTION_HEATMAP_LOADING, true);
    Report.getReports({ ...reportObj, groupBy: 'hour' }).then(heatmapData => {
      let { data } = heatmapData;
      data = clampDataBetweenTimeline(data, reportObj.from, reportObj.to);

      commit(types.default.SET_RESOLUTION_HEATMAP_DATA, data);
      commit(types.default.TOGGLE_RESOLUTION_HEATMAP_LOADING, false);
    });
  },
  fetchAccountSummary({ commit }, reportObj) {
    commit(types.default.SET_ACCOUNT_SUMMARY_STATUS, STATUS.FETCHING);
    Report.getSummary(
      reportObj.from,
      reportObj.to,
      reportObj.type,
      reportObj.id,
      reportObj.groupBy,
      reportObj.businessHours
    )
      .then(accountSummary => {
        commit(types.default.SET_ACCOUNT_SUMMARY, accountSummary.data);
        commit(types.default.SET_ACCOUNT_SUMMARY_STATUS, STATUS.FINISHED);
      })
      .catch(() => {
        commit(types.default.SET_ACCOUNT_SUMMARY_STATUS, STATUS.FAILED);
      });
  },
  fetchBotSummary({ commit }, reportObj) {
    commit(types.default.SET_BOT_SUMMARY_STATUS, STATUS.FETCHING);
    Report.getBotSummary({
      from: reportObj.from,
      to: reportObj.to,
      groupBy: reportObj.groupBy,
      businessHours: reportObj.businessHours,
    })
      .then(botSummary => {
        commit(types.default.SET_BOT_SUMMARY, botSummary.data);
        commit(types.default.SET_BOT_SUMMARY_STATUS, STATUS.FINISHED);
      })
      .catch(() => {
        commit(types.default.SET_BOT_SUMMARY_STATUS, STATUS.FAILED);
      });
  },
  fetchBookingSummary({ commit }, reportObj) {
    commit(types.default.SET_BOOKING_SUMMARY_STATUS, STATUS.FETCHING);
    Report.getBookingSummary({ ...reportObj, metricType: 'booking' })
      .then(bookingSummary => {
        commit(types.default.SET_BOOKING_SUMMARY, bookingSummary.data);
        commit(types.default.SET_BOOKING_SUMMARY_STATUS, STATUS.FINISHED);
      })
      .catch(() => {
        commit(types.default.SET_BOOKING_SUMMARY_STATUS, STATUS.FAILED);
      });
  },
  fetchHandoffSummary({ commit }, reportObj) {
    commit(types.default.SET_HANDOFF_SUMMARY_STATUS, STATUS.FETCHING);
    Report.getBookingSummary({ ...reportObj, metricType: 'handoff' })
      .then(handoffSummary => {
        commit(types.default.SET_HANDOFF_SUMMARY, handoffSummary.data);
        commit(types.default.SET_HANDOFF_SUMMARY_STATUS, STATUS.FINISHED);
      })
      .catch(() => {
        commit(types.default.SET_HANDOFF_SUMMARY_STATUS, STATUS.FAILED);
      });
  },
  fetchAccountConversationMetric({ commit }, params = {}) {
    commit(types.default.TOGGLE_ACCOUNT_CONVERSATION_METRIC_LOADING, true);
    liveReports
      .getConversationMetric(params)
      .then(accountConversationMetric => {
        commit(
          types.default.SET_ACCOUNT_CONVERSATION_METRIC,
          accountConversationMetric.data
        );
        commit(types.default.TOGGLE_ACCOUNT_CONVERSATION_METRIC_LOADING, false);
      })
      .catch(() => {
        commit(types.default.TOGGLE_ACCOUNT_CONVERSATION_METRIC_LOADING, false);
      });
  },
  fetchAgentConversationMetric({ commit }) {
    commit(types.default.TOGGLE_AGENT_CONVERSATION_METRIC_LOADING, true);
    liveReports
      .getGroupedConversations({ groupBy: 'assignee_id' })
      .then(agentConversationMetric => {
        commit(
          types.default.SET_AGENT_CONVERSATION_METRIC,
          agentConversationMetric.data
        );
        commit(types.default.TOGGLE_AGENT_CONVERSATION_METRIC_LOADING, false);
      })
      .catch(() => {
        commit(types.default.TOGGLE_AGENT_CONVERSATION_METRIC_LOADING, false);
      });
  },
  fetchTeamConversationMetric({ commit }) {
    commit(types.default.TOGGLE_TEAM_CONVERSATION_METRIC_LOADING, true);
    liveReports
      .getGroupedConversations({ groupBy: 'team_id' })
      .then(teamMetric => {
        commit(types.default.SET_TEAM_CONVERSATION_METRIC, teamMetric.data);
        commit(types.default.TOGGLE_TEAM_CONVERSATION_METRIC_LOADING, false);
      })
      .catch(() => {
        commit(types.default.TOGGLE_TEAM_CONVERSATION_METRIC_LOADING, false);
      });
  },
  downloadAgentReports(_, reportObj) {
    return Report.getAgentReports(reportObj)
      .then(response => {
        downloadCsvFile(reportObj.fileName, response.data);
        AnalyticsHelper.track(REPORTS_EVENTS.DOWNLOAD_REPORT, {
          reportType: 'agent',
          businessHours: reportObj?.businessHours,
        });
      })
      .catch(error => {
        console.error(error);
      });
  },
  downloadConversationsSummaryReports(_, reportObj) {
    return Report.getConversationsSummaryReports(reportObj)
      .then(response => {
        downloadCsvFile(reportObj.fileName, response.data);
        AnalyticsHelper.track(REPORTS_EVENTS.DOWNLOAD_REPORT, {
          reportType: 'conversations_summary',
          businessHours: reportObj?.businessHours,
        });
      })
      .catch(error => {
        console.error(error);
      });
  },
  downloadLabelReports(_, reportObj) {
    return Report.getLabelReports(reportObj)
      .then(response => {
        downloadCsvFile(reportObj.fileName, response.data);
        AnalyticsHelper.track(REPORTS_EVENTS.DOWNLOAD_REPORT, {
          reportType: 'label',
          businessHours: reportObj?.businessHours,
        });
      })
      .catch(error => {
        console.error(error);
      });
  },
  downloadInboxReports(_, reportObj) {
    return Report.getInboxReports(reportObj)
      .then(response => {
        downloadCsvFile(reportObj.fileName, response.data);
        AnalyticsHelper.track(REPORTS_EVENTS.DOWNLOAD_REPORT, {
          reportType: 'inbox',
          businessHours: reportObj?.businessHours,
        });
      })
      .catch(error => {
        console.error(error);
      });
  },
  downloadTeamReports(_, reportObj) {
    return Report.getTeamReports(reportObj)
      .then(response => {
        downloadCsvFile(reportObj.fileName, response.data);
        AnalyticsHelper.track(REPORTS_EVENTS.DOWNLOAD_REPORT, {
          reportType: 'team',
          businessHours: reportObj?.businessHours,
        });
      })
      .catch(error => {
        console.error(error);
      });
  },
  downloadAccountConversationHeatmap(_, reportObj) {
    Report.getConversationTrafficCSV({ daysBefore: reportObj.daysBefore })
      .then(response => {
        downloadCsvFile(
          generateFileName({
            type: 'Conversation traffic',
            to: reportObj.to,
          }),
          response.data
        );

        AnalyticsHelper.track(REPORTS_EVENTS.DOWNLOAD_REPORT, {
          reportType: 'conversation_heatmap',
          businessHours: false,
        });
      })
      .catch(error => {
        console.error(error);
      });
  },
  fetchTwilioUsage({ commit }, params) {
    commit(types.default.SET_TWILIO_USAGE, { data: null, isFetching: true });
    return Report.getTwilioUsage(params)
      .then(response => {
        commit(types.default.SET_TWILIO_USAGE, {
          data: response.data,
          isFetching: false,
        });
      })
      .catch(() => {
        commit(types.default.SET_TWILIO_USAGE, {
          data: null,
          isFetching: false,
        });
      });
  },
  fetchWalletBalance({ commit }) {
    commit(types.default.SET_WALLET_BALANCE, { data: null, isFetching: true });
    return Report.getWalletBalance()
      .then(response => {
        commit(types.default.SET_WALLET_BALANCE, {
          data: response.data,
          isFetching: false,
        });
      })
      .catch(() => {
        commit(types.default.SET_WALLET_BALANCE, {
          data: null,
          isFetching: false,
        });
      });
  },
  fetchAttributionValues({ commit, state: currentState }) {
    if (currentState.attributionValues.data) {
      return Promise.resolve();
    }

    commit(types.default.SET_ATTRIBUTION_VALUES, {
      data: null,
      isFetching: true,
    });
    return Report.getAttributionValues()
      .then(response => {
        commit(types.default.SET_ATTRIBUTION_VALUES, {
          data: response.data,
          isFetching: false,
        });
      })
      .catch(() => {
        commit(types.default.SET_ATTRIBUTION_VALUES, {
          data: null,
          isFetching: false,
        });
      });
  },
  fetchAttributionReport({ commit, state: currentState }, payload = {}) {
    const { force = false, ...filters } = payload;
    const cacheKey = JSON.stringify(filters);
    if (
      !force &&
      currentState.attributionReport.params === cacheKey &&
      currentState.attributionReport.data !== null
    ) {
      return Promise.resolve();
    }

    commit(types.default.SET_ATTRIBUTION_REPORT, {
      data: currentState.attributionReport.data,
      params: currentState.attributionReport.params,
      isFetching: true,
    });
    return Report.getAttributionReport(filters)
      .then(response => {
        commit(types.default.SET_ATTRIBUTION_REPORT, {
          data: response.data,
          params: cacheKey,
          isFetching: false,
        });
      })
      .catch(() => {
        commit(types.default.SET_ATTRIBUTION_REPORT, {
          data: null,
          params: null,
          isFetching: false,
        });
      });
  },
};

const mutations = {
  [types.default.SET_ACCOUNT_REPORTS](_state, { metric, data }) {
    _state.accountReport.data[metric] = data;
  },
  [types.default.SET_HEATMAP_DATA](_state, heatmapData) {
    _state.overview.accountConversationHeatmap = heatmapData;
  },
  [types.default.SET_RESOLUTION_HEATMAP_DATA](_state, heatmapData) {
    _state.overview.accountResolutionHeatmap = heatmapData;
  },
  [types.default.TOGGLE_ACCOUNT_REPORT_LOADING](_state, { metric, value }) {
    _state.accountReport.isFetching[metric] = value;
  },
  [types.default.SET_BOT_SUMMARY_STATUS](_state, status) {
    _state.botSummaryFetchingStatus = status;
  },
  [types.default.SET_ACCOUNT_SUMMARY_STATUS](_state, status) {
    _state.accountSummaryFetchingStatus = status;
  },
  [types.default.TOGGLE_HEATMAP_LOADING](_state, flag) {
    _state.overview.uiFlags.isFetchingAccountConversationsHeatmap = flag;
  },
  [types.default.TOGGLE_RESOLUTION_HEATMAP_LOADING](_state, flag) {
    _state.overview.uiFlags.isFetchingAccountResolutionsHeatmap = flag;
  },
  [types.default.SET_ACCOUNT_SUMMARY](_state, summaryData) {
    _state.accountSummary = summaryData;
  },
  [types.default.SET_BOT_SUMMARY](_state, summaryData) {
    _state.botSummary = summaryData;
  },
  [types.default.SET_BOOKING_SUMMARY](_state, summaryData) {
    _state.bookingSummary = summaryData;
  },
  [types.default.SET_BOOKING_SUMMARY_STATUS](_state, status) {
    _state.bookingSummaryFetchingStatus = status;
  },
  [types.default.SET_HANDOFF_SUMMARY](_state, summaryData) {
    _state.handoffSummary = summaryData;
  },
  [types.default.SET_HANDOFF_SUMMARY_STATUS](_state, status) {
    _state.handoffSummaryFetchingStatus = status;
  },
  [types.default.SET_ACCOUNT_CONVERSATION_METRIC](_state, metricData) {
    _state.overview.accountConversationMetric = metricData;
  },
  [types.default.TOGGLE_ACCOUNT_CONVERSATION_METRIC_LOADING](_state, flag) {
    _state.overview.uiFlags.isFetchingAccountConversationMetric = flag;
  },
  [types.default.SET_AGENT_CONVERSATION_METRIC](_state, metricData) {
    _state.overview.agentConversationMetric = metricData;
  },
  [types.default.TOGGLE_AGENT_CONVERSATION_METRIC_LOADING](_state, flag) {
    _state.overview.uiFlags.isFetchingAgentConversationMetric = flag;
  },
  [types.default.SET_TEAM_CONVERSATION_METRIC](_state, metricData) {
    _state.overview.teamConversationMetric = metricData;
  },
  [types.default.TOGGLE_TEAM_CONVERSATION_METRIC_LOADING](_state, flag) {
    _state.overview.uiFlags.isFetchingTeamConversationMetric = flag;
  },
  [types.default.SET_BOOKING_STATS_CACHE](_state, { data, params, timestamp }) {
    _state.bookingStatsCache.data = data;
    _state.bookingStatsCache.params = params;
    _state.bookingStatsCache.timestamp = timestamp;
  },
  [types.default.SET_TWILIO_USAGE](_state, { data, isFetching }) {
    _state.twilioUsage.data = data;
    _state.twilioUsage.isFetching = isFetching;
  },
  [types.default.SET_WALLET_BALANCE](_state, { data, isFetching }) {
    _state.walletBalance.data = data;
    _state.walletBalance.isFetching = isFetching;
  },
  [types.default.SET_ATTRIBUTION_VALUES](_state, { data, isFetching }) {
    _state.attributionValues.data = data;
    _state.attributionValues.isFetching = isFetching;
  },
  [types.default.SET_ATTRIBUTION_REPORT](_state, { data, params, isFetching }) {
    _state.attributionReport.data = data;
    _state.attributionReport.params = params;
    _state.attributionReport.isFetching = isFetching;
  },
};

export default {
  state,
  getters,
  actions,
  mutations,
};
