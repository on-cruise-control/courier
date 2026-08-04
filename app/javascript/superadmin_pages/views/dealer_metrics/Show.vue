<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import CustomLineChart from 'shared/components/charts/CustomLineChart.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useLiveRefresh } from 'dashboard/composables/useLiveRefresh';

const props = defineProps({
  componentData: {
    type: Object,
    default: () => ({}),
  },
});

const RANGE_OPTIONS = [
  { key: 'last_7_days', label: 'Last 7 days', days: 6 },
  { key: 'last_14_days', label: 'Last 14 days', days: 13 },
  { key: 'last_30_days', label: 'Last 30 days', days: 29 },
  { key: 'last_90_days', label: 'Last 90 days', days: 89 },
  { key: 'custom', label: 'Custom' },
];

const metricsData = ref(props.componentData || {});

const filters = computed(() => metricsData.value.filters || {});
const section = computed(() => metricsData.value.section || {});

const selectedRangeKey = ref('last_7_days');
const selectedSince = ref('');
const selectedUntil = ref('');
const selectedDealershipId = ref('');
const selectedAccountId = ref('');
const selectedUserId = ref('');
const isLoading = ref(false);
const fetchSequence = ref(0);
const currentTime = ref(Date.now());
const isUserDetailOpen = ref(false);
let currentTimeInterval = null;

const formatDateInput = date => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const applyPresetRange = rangeKey => {
  const option = RANGE_OPTIONS.find(item => item.key === rangeKey);
  if (!option || rangeKey === 'custom') {
    return;
  }

  const today = new Date();
  const from = new Date(today);
  from.setDate(today.getDate() - option.days);

  selectedSince.value = formatDateInput(from);
  selectedUntil.value = formatDateInput(today);
};

const syncStateFromPayload = payload => {
  metricsData.value = payload || {};
  const currentFilters = payload?.filters || {};
  selectedRangeKey.value = currentFilters.selectedRangeKey || 'last_7_days';
  selectedSince.value = currentFilters.since || '';
  selectedUntil.value = currentFilters.until || '';
  selectedDealershipId.value = currentFilters.selectedDealershipId || '';
  selectedAccountId.value = currentFilters.selectedAccountId || '';
  selectedUserId.value = currentFilters.selectedUserId || '';
};

syncStateFromPayload(props.componentData || {});

const fetchMetrics = async (overrides = {}) => {
  const requestId = fetchSequence.value + 1;
  fetchSequence.value = requestId;
  isLoading.value = true;

  try {
    const url = `${buildUrl(overrides)}&format=json`;
    const response = await fetch(url, {
      headers: {
        Accept: 'application/json',
      },
      credentials: 'same-origin',
    });

    if (!response.ok) {
      throw new Error('Failed to fetch dealer metrics');
    }

    const payload = await response.json();
    if (requestId !== fetchSequence.value) {
      return;
    }
    syncStateFromPayload(payload);
    window.history.replaceState({}, '', buildUrl(overrides));
  } catch (error) {
    // Keep the current view intact if the refresh fails.
    console.error(error);
  } finally {
    if (requestId === fetchSequence.value) {
      isLoading.value = false;
    }
  }
};

const onRangeChange = async () => {
  if (selectedRangeKey.value !== 'custom') {
    applyPresetRange(selectedRangeKey.value);
  }

  await fetchMetrics();
};

const onDealershipChange = async () => {
  await fetchMetrics();
};

const onDateChange = async () => {
  await fetchMetrics();
};

const { startRefetching } = useLiveRefresh(fetchMetrics);

onMounted(() => {
  currentTimeInterval = window.setInterval(() => {
    currentTime.value = Date.now();
  }, 1000);

  if (section.value.key === 'bookings') {
    fetchMetrics();
  }
  startRefetching();
});

onBeforeUnmount(() => {
  if (currentTimeInterval) {
    window.clearInterval(currentTimeInterval);
  }
});

const buildUrl = overrides => {
  const params = new URLSearchParams();

  params.set('page', overrides.page || section.value.key || 'conversations');
  params.set('range_key', overrides.rangeKey || selectedRangeKey.value);

  const dealershipId = Object.prototype.hasOwnProperty.call(overrides, 'dealershipId')
    ? overrides.dealershipId
    : selectedDealershipId.value;

  if (dealershipId) {
    params.set('dealership_id', dealershipId);
  }

  const accountId = Object.prototype.hasOwnProperty.call(overrides, 'accountId')
    ? overrides.accountId
    : selectedAccountId.value;

  if (accountId) {
    params.set('account_id', accountId);
  }

  const userId = Object.prototype.hasOwnProperty.call(overrides, 'userId')
    ? overrides.userId
    : selectedUserId.value;

  if (userId) {
    params.set('user_id', userId);
  }

  const sinceValue = overrides.since || selectedSince.value;
  const untilValue = overrides.until || selectedUntil.value;

  if (sinceValue) {
    params.set('since', sinceValue);
  }

  if (untilValue) {
    params.set('until', untilValue);
  }

  return `/super_admin/dealer_metrics?${params.toString()}`;
};

const rowColumns = computed(() => {
  const rows = section.value.dealershipRows || [];
  if (!rows.length) {
    return [];
  }

  return Object.keys(rows[0]).filter(
    key => !['dealershipId', 'dealershipName'].includes(key)
  );
});

const chartPanels = computed(() => {
  const labels = section.value.chartData?.labels || [];
  const datasets = section.value.chartData?.datasets || [];

  return datasets.map(dataset => ({
    label: displayChartLabel(dataset.label),
    value:
      section.value.chartSummaryValues?.[dataset.label] ??
      section.value.chartSummaryValue ??
      matchingCardValue(dataset.label),
    percentage: false,
    collection: {
      labels,
      datasets: [
        {
          data: dataset.data || [],
          borderColor: '#1f3c4a',
          backgroundColor: 'rgba(15, 23, 42, 0.12)',
          pointBackgroundColor: '#1f3c4a',
          pointBorderColor: '#1f3c4a',
          tension: 0.35,
          fill: true,
        },
      ],
    },
  }));
});

const secondaryCards = computed(() => {
  const renderedChartLabels = chartPanels.value.map(panel => panel.label);
  return (section.value.cards || []).filter(card => {
    const cardLabel = normalizeLabel(card.label);
    return !renderedChartLabels.some(label => cardLabel === normalizeLabel(label));
  });
});

const compactCards = computed(() => {
  if (section.value.key === 'agent_sessions') {
    return [];
  }

  if (showChartPanels.value) {
    return secondaryCards.value;
  }

  return section.value.cards || [];
});

const displayChartLabel = label => {
  if (label === 'Messages') {
    return 'Messages avg';
  }

  if (label === 'Conversations' && shouldUseAverageLabels.value) {
    return 'Conversations avg';
  }

  return label;
};

const chartPanelKey = panel =>
  [
    section.value.key,
    selectedRangeKey.value || 'range',
    selectedDealershipId.value || 'all',
    panel.label,
    JSON.stringify(panel.collection.datasets?.[0]?.data || []),
  ].join('-');

const showChartPanels = computed(() => {
  if (section.value.key === 'agent_sessions') {
    return false;
  }

  return chartPanels.value.length > 0;
});
const chartPanelsGridClass = computed(() =>
  section.value.key === 'conversations' ? 'md:grid-cols-2' : 'md:grid-cols-1'
);

const showRangeControls = computed(
  () => section.value.key !== 'agent_sessions' || isUserDetailOpen.value
);
const showDealershipFilter = computed(
  () => section.value.key !== 'agent_sessions' || !isUserDetailOpen.value
);
const showAgentSessionsDealershipColumn = computed(
  () => section.value.key !== 'agent_sessions' || !selectedDealershipId.value
);
const rangeFilterWidthClass = computed(() => 'md:w-1/3');
const dealershipFilterWidthClass = computed(() => 'md:w-1/3');
const isBookingsLoading = computed(() => section.value.key === 'bookings' && isLoading.value);
const bookingsLoadingCards = computed(() => {
  if (selectedDealershipId.value) {
    return [
      { label: 'Avg bookings per day' },
      { label: 'Booking rate' },
    ];
  }

  return [
    { label: 'Avg bookings per dealer' },
    { label: 'Avg bookings per day' },
    { label: 'Booking rate' },
  ];
});
const shouldUseAverageLabels = computed(
  () => section.value.key === 'conversations' && !selectedDealershipId.value
);

const lineChartOptions = {
  scales: {
    x: {
      grid: {
        drawOnChartArea: false,
      },
    },
    y: {
      beginAtZero: true,
      ticks: {
        callback: value => `${value}m`,
      },
      grid: {
        drawOnChartArea: false,
      },
    },
  },
  plugins: {
    legend: {
      display: false,
    },
  },
};

const countChartOptions = {
  scales: {
    x: {
      grid: {
        drawOnChartArea: false,
      },
    },
    y: {
      beginAtZero: true,
      ticks: {
        precision: 0,
        callback: value => Number(value).toLocaleString(),
      },
      grid: {
        drawOnChartArea: false,
      },
    },
  },
  plugins: {
    legend: {
      display: false,
    },
  },
};

const formatNumber = value => {
  const numericValue = Number(value || 0);
  return Number.isInteger(numericValue)
    ? numericValue.toLocaleString()
    : numericValue.toLocaleString(undefined, {
        minimumFractionDigits: 0,
        maximumFractionDigits: 2,
      });
};

const formatPercent = value => `${formatNumber(value)}%`;

const formatDateTime = value => {
  if (!value) {
    return '-';
  }

  return new Date(value).toLocaleString();
};

const formatDuration = value => {
  if (value === null || value === undefined || value === '') {
    return '-';
  }

  const totalSeconds = Number(value || 0);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  return [hours, minutes, seconds]
    .map(segment => String(segment).padStart(2, '0'))
    .join(':');
};

const displaySessionDuration = user => {
  if (user.sessionStartedAt) {
    const startedAt = Date.parse(user.sessionStartedAt);
    if (!Number.isNaN(startedAt)) {
      const liveDurationSeconds =
        Number(user.sessionDurationSeconds || 0) +
        Math.max(Math.floor((currentTime.value - startedAt) / 1000), 0);
      return formatDuration(liveDurationSeconds);
    }
  }

  return formatDuration(user.sessionDurationSeconds);
};

const selectedUserSession = computed(() => section.value.selectedUserSession || null);
const selectedUserLiveRow = computed(() => {
  const selectedUser = selectedUserSession.value;
  if (!selectedUser) {
    return null;
  }

  return (section.value.users || []).find(
    user =>
      String(user.userId) === String(selectedUser.userId) &&
      (
        String(user.dealershipId) === String(selectedUser.dealershipId) ||
        String(user.accountId) === String(selectedUser.accountId) ||
        String(user.accountId) === String(selectedUser.dealershipId)
      )
  ) || null;
});

const displaySelectedUserDuration = computed(() => {
  const selectedUser = selectedUserSession.value;
  if (!selectedUser) {
    return '-';
  }

  const liveRow = selectedUserLiveRow.value;
  const storedDurationSeconds = Number(
    selectedUser.storedDurationSeconds ?? liveRow?.sessionDurationSeconds ?? 0
  );
  const sessionStartedAt = selectedUser.sessionStartedAt || liveRow?.sessionStartedAt;

  if (!sessionStartedAt) {
    return formatDuration(storedDurationSeconds);
  }

  const startedAt = Date.parse(sessionStartedAt);
  if (Number.isNaN(startedAt)) {
    return formatDuration(storedDurationSeconds);
  }

  const liveDurationSeconds =
    storedDurationSeconds + Math.max(Math.floor((currentTime.value - startedAt) / 1000), 0);

  return formatDuration(liveDurationSeconds);
});

const sessionChartPanel = computed(() => {
  const labels = selectedUserSession.value?.chartData?.labels || [];
  const datasets = selectedUserSession.value?.chartData?.datasets || [];

  return {
    collection: {
      labels,
      datasets: datasets.map(dataset => ({
        data: dataset.data || [],
        borderColor: dataset.borderColor || '#1f3c4a',
        backgroundColor: 'rgba(15, 23, 42, 0.12)',
        pointBackgroundColor: '#1f3c4a',
        pointBorderColor: '#1f3c4a',
        tension: 0.35,
        fill: true,
      })),
    },
  };
});

const openUserDetail = async user => {
  isUserDetailOpen.value = true;
  await fetchMetrics({
    page: 'agent_sessions',
    accountId: user.accountId || user.dealershipId,
    dealershipId: user.dealershipId,
    userId: user.userId,
  });
};

const closeUserDetail = async () => {
  isUserDetailOpen.value = false;
  selectedDealershipId.value = '';
  selectedAccountId.value = '';
  selectedUserId.value = '';
  await fetchMetrics({
    page: 'agent_sessions',
    accountId: '',
    userId: '',
  });
};

const formatCell = (column, value) => {
  if (column.toLowerCase().includes('rate')) {
    return formatPercent(value);
  }

  if (typeof value === 'number') {
    return formatNumber(value);
  }

  return value;
};

const normalizeLabel = value =>
  String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

const matchingCardValue = datasetLabel => {
  const datasetKey = normalizeLabel(datasetLabel);
  const cards = section.value.cards || [];

  const exactMatch = cards.find(item => normalizeLabel(item.label) === datasetKey);
  if (exactMatch) {
    return exactMatch.value || 0;
  }

  const card = cards.find(item => {
    const cardKey = normalizeLabel(item.label);
    return cardKey.includes(datasetKey) || datasetKey.includes(cardKey);
  });

  return card?.value || 0;
};

const prettyLabel = key =>
  key
    .replace(/([A-Z])/g, ' $1')
    .replace(/^./, char => char.toUpperCase());
</script>

<template>
  <div class="w-full h-full p-6">
    <header class="flex flex-col gap-4">
      <div class="flex flex-col gap-1">
        <h1 class="text-2xl font-semibold text-slate-900">Product Metrics</h1>
      </div>

      <form
        :aria-busy="isLoading"
        class="flex flex-col gap-3 md:flex-row md:items-center"
        action="/super_admin/dealer_metrics"
        method="get"
      >
        <input :value="section.key || 'conversations'" name="page" type="hidden" />

        <template v-if="showRangeControls">
          <label class="w-full" :class="rangeFilterWidthClass">
            <select
              v-model="selectedRangeKey"
              class="dealer-metrics-select w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-800 shadow-sm"
              name="range_key"
              @change="onRangeChange"
            >
              <option
                v-for="option in RANGE_OPTIONS"
                :key="option.key"
                :value="option.key"
              >
                {{ option.label }}
              </option>
            </select>
          </label>
        </template>

        <label v-if="showDealershipFilter" class="w-full" :class="dealershipFilterWidthClass">
          <select
            v-model="selectedDealershipId"
            class="dealer-metrics-select w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-800 shadow-sm"
            name="dealership_id"
            @change="onDealershipChange"
          >
            <option value="">All dealerships</option>
            <option
              v-for="dealership in filters.dealerships"
              :key="dealership.id"
              :value="dealership.id"
            >
              {{ dealership.name }}
            </option>
          </select>
        </label>

        <template v-if="showRangeControls && selectedRangeKey === 'custom'">
          <input
            v-model="selectedSince"
            class="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-800 shadow-sm md:w-48"
            name="since"
            type="date"
            @change="onDateChange"
          />
          <input
            v-model="selectedUntil"
            class="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-800 shadow-sm md:w-48"
            name="until"
            type="date"
            @change="onDateChange"
          />
        </template>
      </form>
    </header>

    <section class="mt-6 flex flex-col gap-6">
      <div
        v-if="isBookingsLoading"
        class="grid gap-4 md:grid-cols-2 xl:grid-cols-4"
      >
        <article
          v-for="card in bookingsLoadingCards"
          :key="`bookings-skeleton-${card.label}`"
          class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
        >
          <p class="text-sm text-slate-500">{{ card.label }}</p>
          <div class="mt-3 flex min-h-[2rem] items-center">
            <Spinner :size="24" class="text-slate-500" />
          </div>
        </article>
      </div>

      <div
        v-else-if="compactCards.length"
        class="grid gap-4 md:grid-cols-2 xl:grid-cols-4"
      >
        <article
          v-for="card in compactCards"
          :key="card.label"
          class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
        >
          <p class="text-sm text-slate-500">{{ card.label }}</p>
          <p class="mt-2 text-2xl font-semibold text-slate-900">
            <template v-if="isBookingsLoading">
              <Spinner :size="24" class="text-slate-500" />
            </template>
            <template v-else>
              {{ card.percentage ? formatPercent(card.value) : formatNumber(card.value) }}
            </template>
          </p>
        </article>
      </div>

      <div
        v-if="isBookingsLoading"
        class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
      >
        <article class="min-h-[22rem]">
          <p class="text-sm text-slate-500">Bookings</p>
          <p class="mt-1 text-2xl font-semibold text-slate-900">
            <Spinner :size="24" class="text-slate-500" />
          </p>

          <div class="mt-4 h-72 rounded-2xl border border-dashed border-slate-200 bg-slate-50">
            <div class="flex h-full items-center justify-center">
              <Spinner :size="32" class="text-slate-500" />
            </div>
          </div>
        </article>
      </div>

      <div
        v-else-if="showChartPanels"
        class="min-w-0 overflow-hidden rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
      >
        <div class="grid min-w-0 gap-6" :class="chartPanelsGridClass">
          <article
            v-for="panel in chartPanels"
            :key="panel.label"
            class="min-h-[22rem] min-w-0 max-w-full"
          >
            <p class="text-sm text-slate-500">{{ panel.label }}</p>
            <p class="mt-1 text-2xl font-semibold text-slate-900">
              <template v-if="isBookingsLoading">
                <Spinner :size="24" class="text-slate-500" />
              </template>
              <template v-else>
                {{ formatNumber(panel.value) }}
              </template>
            </p>

            <div class="mt-4 h-72 w-full min-w-0 max-w-full overflow-hidden">
              <div
                v-if="isBookingsLoading"
                class="flex h-full items-center justify-center"
              >
                <Spinner :size="32" class="text-slate-500" />
              </div>
              <div v-else class="h-full w-full min-w-0">
                <CustomLineChart
                  :key="chartPanelKey(panel)"
                  :collection="panel.collection"
                  :chart-options="countChartOptions"
                  class="h-full w-full"
                />
              </div>
            </div>
          </article>
        </div>
      </div>

      <div
        v-if="section.key !== 'bookings' && (section.dealershipRows || []).length && !(section.key === 'agent_sessions' && isUserDetailOpen)"
        class="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm"
      >
        <table class="dealer-metrics-table min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50 text-left text-slate-600">
            <tr>
              <th class="!pl-8 !pr-6 py-3 font-medium">Dealership</th>
              <th
                v-for="column in rowColumns"
                :key="column"
                class="px-6 py-3 font-medium last:!pr-8"
              >
                {{ prettyLabel(column) }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 bg-white">
            <tr
              v-for="row in section.dealershipRows || []"
              :key="row.dealershipId"
            >
              <td class="!pl-8 !pr-6 py-3">
                <a
                  :href="buildUrl({ dealershipId: row.dealershipId })"
                  class="dealer-metrics-link font-medium text-woot-500 no-underline hover:no-underline"
                >
                  {{ row.dealershipName }}
                </a>
              </td>
              <td
                v-for="column in rowColumns"
                :key="column"
                class="px-6 py-3 text-slate-700 last:!pr-8"
              >
                {{ formatCell(column, row[column]) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        v-if="section.key === 'bookings' && !isBookingsLoading"
        class="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm"
      >
        <table class="dealer-metrics-table min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50 text-left text-slate-600">
            <tr>
              <th class="!pl-8 !pr-6 py-3 font-medium">Dealership</th>
              <th class="px-6 py-3 font-medium">Bookings</th>
              <th class="!pr-8 px-6 py-3 font-medium">Booking Rate</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 bg-white">
            <tr v-if="!(section.dealershipRows || []).length">
              <td class="!pl-8 !pr-8 py-6 text-slate-500" colspan="3">
                No bookings found for this filter.
              </td>
            </tr>
            <tr
              v-for="row in section.dealershipRows || []"
              :key="row.dealershipId"
            >
              <td class="!pl-8 !pr-6 py-3">
                <a
                  :href="buildUrl({ dealershipId: row.dealershipId })"
                  class="dealer-metrics-link font-medium text-woot-500 no-underline hover:no-underline"
                >
                  {{ row.dealershipName }}
                </a>
              </td>
              <td class="px-6 py-3 text-slate-700">
                {{ formatNumber(row.bookings) }}
              </td>
              <td class="!pr-8 px-6 py-3 text-slate-700">
                {{ formatCell('bookingRate', row.bookingRate) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        v-if="section.key === 'agent_sessions'"
        class="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm"
      >
        <div v-if="isUserDetailOpen" class="p-5">
          <template v-if="selectedUserSession">
          <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div>
              <h2 class="text-lg font-semibold text-slate-900">{{ selectedUserSession.userName }}</h2>
              <p class="text-sm text-slate-500">{{ selectedUserSession.userEmail }}</p>
            </div>

            <button
              class="w-fit self-start rounded-2xl border border-slate-200 bg-white px-4 py-2 text-sm font-medium text-slate-700 shadow-sm md:self-auto"
              type="button"
              @click="closeUserDetail"
            >
              Back
            </button>
          </div>

          <div class="mt-5 flex flex-col gap-4 items-start">
            <article
              v-for="card in selectedUserSession.cards || []"
              :key="card.label"
              class="inline-flex w-fit max-w-full shrink-0 flex-col items-start rounded-2xl border border-slate-200 bg-slate-50 p-4"
            >
              <p class="text-sm text-slate-500">{{ card.label }}</p>
              <p class="mt-2 inline-block min-w-[8ch] font-mono text-2xl font-semibold tabular-nums text-slate-900 whitespace-nowrap">
                {{ card.label === 'Total duration' ? displaySelectedUserDuration : card.value }}
              </p>
            </article>
          </div>

          <div class="mt-6 h-80">
            <CustomLineChart
              :collection="sessionChartPanel.collection"
              :chart-options="lineChartOptions"
            />
          </div>
          </template>

          <div
            v-else-if="isLoading"
            class="flex min-h-[20rem] items-center justify-center text-sm text-slate-500"
          >
            Loading user sessions…
          </div>

          <div
            v-else
            class="flex min-h-[20rem] items-center justify-center text-sm text-slate-500"
          >
            No session data found for this user.
          </div>
        </div>

        <table
          v-if="!isUserDetailOpen"
          class="dealer-metrics-table min-w-[1200px] w-full divide-y divide-slate-200 text-sm"
        >
          <thead class="bg-slate-50 text-left text-slate-600">
            <tr>
              <th v-if="showAgentSessionsDealershipColumn" class="!pl-8 !pr-6 py-3 font-medium">Dealership</th>
              <th class="px-6 py-3 font-medium">User</th>
              <th class="px-6 py-3 font-medium">Session state</th>
              <th class="px-6 py-3 font-medium">Session started</th>
              <th class="!pr-8 px-6 py-3 font-medium whitespace-nowrap">Duration</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 bg-white">
            <tr v-if="!(section.users || []).length">
              <td class="!pl-8 !pr-8 py-6 text-slate-500" :colspan="showAgentSessionsDealershipColumn ? 5 : 4">
                No dealership users found for this filter.
              </td>
            </tr>
            <tr
              v-for="user in section.users || []"
              :key="`${user.accountId}-${user.userId}`"
            >
              <td v-if="showAgentSessionsDealershipColumn" class="!pl-8 !pr-6 py-3 text-slate-700">
                <div>{{ user.dealershipName }}</div>
              </td>
              <td class="px-6 py-3 text-slate-700">
                <a
                  href="#"
                  class="dealer-metrics-link inline-block font-medium text-woot-500 no-underline hover:no-underline"
                  @click.prevent="openUserDetail({ ...user, accountId: user.accountId || user.dealershipId })"
                >
                  {{ user.userName }}
                </a>
                <div class="text-xs text-slate-500">{{ user.userEmail }}</div>
              </td>
              <td class="px-6 py-3 text-slate-700">{{ prettyLabel(user.sessionState || '-') }}</td>
              <td class="px-6 py-3 text-slate-700">{{ formatDateTime(user.sessionStartedAt) }}</td>
              <td class="!pr-8 px-6 py-3 text-slate-700 whitespace-nowrap">
                <span class="inline-block min-w-[9ch] tabular-nums whitespace-nowrap">
                  {{ displaySessionDuration(user) }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>
</template>

<style>
.dealer-metrics-select {
  -webkit-appearance: none;
  appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 20 20' fill='none'%3E%3Cpath d='M5.5 8l4.5 4 4.5-4' stroke='%236B7280' stroke-width='1.75' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 1.35rem center;
  background-size: 14px 14px;
  padding-right: 4rem !important;
}

.dealer-metrics-table th:first-child,
.dealer-metrics-table td:first-child {
  padding-left: 2rem !important;
}

.dealer-metrics-table th:last-child,
.dealer-metrics-table td:last-child {
  padding-right: 2rem !important;
}

.dealer-metrics-table a,
.dealer-metrics-link {
  text-decoration: none !important;
}

.dealer-metrics-table tbody tr > * {
  border-bottom: 1px solid rgb(241 245 249) !important;
}

.dealer-metrics-table tbody tr:last-child > * {
  border-bottom-color: transparent !important;
}
</style>
