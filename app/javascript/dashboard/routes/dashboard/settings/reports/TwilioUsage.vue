<script>
import { mapGetters } from 'vuex';
import ReportHeader from './components/ReportHeader.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

export default {
  name: 'TwilioUsageReports',
  components: {
    ReportHeader,
    Icon,
  },
  data() {
    return {
      selectedPeriod: { label: 'This Month', value: 'this_month' },
      periods: [
        { label: 'Today', value: 'today' },
        { label: 'Yesterday', value: 'yesterday' },
        { label: 'This month', value: 'this_month' },
        { label: 'Last month', value: 'last_month' },
      ],
      expandedRows: [],
    };
  },
  computed: {
    ...mapGetters({
      twilioUsage: 'getTwilioUsage',
      isFetching: 'isFetchingTwilioUsage',
    }),
    totalUsage() {
      return this.twilioUsage?.total_usage || {};
    },
    categories() {
      return this.twilioUsage?.categories || [];
    },
    flattenedCategories() {
      const items = [];
      const flatten = (nodes) => {
        nodes.forEach(node => {
          items.push(node);
          if (this.isExpanded(node.category) && node.children) {
            flatten(node.children);
          }
        });
      };
      flatten(this.categories);
      return items;
    },
  },
  mounted() {
    this.fetchAllData();
  },
  methods: {
    fetchAllData() {
      this.$store.dispatch('fetchTwilioUsage', {
        period: this.selectedPeriod.value,
      });
    },
    onPeriodChange(selectedRange) {
      if (selectedRange) {
        this.selectedPeriod = selectedRange;
        this.fetchAllData();
      }
    },
    toggleRow(id) {
      const index = this.expandedRows.indexOf(id);
      if (index >= 0) {
        this.expandedRows.splice(index, 1);
      } else {
        this.expandedRows.push(id);
      }
    },
    isExpanded(id) {
      return this.expandedRows.includes(id);
    },
    nodeHasChildren(node) {
      return node.children && node.children.length > 0;
    },
    formatCurrency(value) {
      if (value === undefined || value === null) return '$0.00';
      return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        minimumFractionDigits: 2,
        maximumFractionDigits: 4,
      }).format(value);
    },
    formatNumber(value) {
      if (value === undefined || value === null) return '';
      return new Intl.NumberFormat('en-US').format(value);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <ReportHeader :header-title="$t('TWILIO_REPORTS.HEADER')" />
    
    <div class="px-0 flex flex-col justify-between gap-3 md:flex-row">
      <div class="w-full grid gap-y-2 gap-x-1.5 grid-cols-[repeat(auto-fill,minmax(250px,1fr))]">
        <div class="multiselect-wrap--small">
          <multiselect
            v-model="selectedPeriod"
            class="no-margin"
            track-by="value"
            label="label"
            :placeholder="$t('FORMS.MULTISELECT.SELECT_ONE')"
            selected-label="Selected"
            :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
            deselect-label=""
            :options="periods"
            :searchable="false"
            :allow-empty="false"
            @select="onPeriodChange"
          />
        </div>
      </div>
    </div>

    <div v-if="isFetching" class="flex items-center justify-center p-20">
      <woot-loading-state :message="$t('TWILIO_REPORTS.LOADING')" />
    </div>

    <div v-else-if="twilioUsage" class="flex flex-col gap-6">
      <!-- Summary Card -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="bg-n-solid-2 p-6 rounded-xl border border-n-weak shadow-sm">
          <p class="text-sm text-n-slate-11 font-medium mb-1">{{ $t('TWILIO_REPORTS.METRICS.TOTAL_COST') }}</p>
          <p class="text-2xl font-bold text-n-slate-12">
            {{ formatCurrency(totalUsage.price) }}
          </p>
        </div>
        <div class="bg-n-solid-2 p-6 rounded-xl border border-n-weak shadow-sm">
          <p class="text-sm text-n-slate-11 font-medium mb-1">{{ $t('TWILIO_REPORTS.METRICS.PERIOD') }}</p>
          <p class="text-sm font-medium text-n-slate-12">
            {{ $t('TWILIO_REPORTS.PERIOD_DATE_RANGE', { startDate: totalUsage.period?.start_date || 'N/A', endDate: totalUsage.period?.end_date || 'N/A' }) }}
          </p>
        </div>
      </div>

      <!-- Categories Table -->
      <div class="bg-n-solid-2 overflow-hidden border border-n-weak rounded-xl shadow-sm">

        <div class="overflow-x-auto">
          <table class="w-full text-sm text-left text-n-slate-11 table-fixed">
            <thead class="text-xs uppercase bg-n-solid-1 text-n-slate-10 border-b border-n-weak">
              <tr>
                <th scope="col" class="px-6 py-3 w-[50%]">{{ $t('TWILIO_REPORTS.TABLE.CATEGORY') }}</th>
                <th scope="col" class="px-6 py-3 w-[25%]">{{ $t('TWILIO_REPORTS.TABLE.USAGE') }}</th>
                <th scope="col" class="px-6 py-3 w-[25%] text-right">{{ $t('TWILIO_REPORTS.TABLE.COST') }}</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr 
                v-for="category in flattenedCategories" 
                :key="category.category" 
                class="bg-n-solid-2 hover:bg-n-alpha-1 transition-colors cursor-pointer group"
                @click="nodeHasChildren(category) ? toggleRow(category.category) : null"
              >
                <th scope="row" class="px-6 py-4 font-medium text-n-slate-12 w-[50%]">
                  <div class="flex items-center gap-2" :style="{ paddingLeft: `${category.level * 20}px` }">
                    <span v-if="nodeHasChildren(category)" class="inline-flex items-center justify-center w-4 h-4 text-n-slate-12 transition-colors">
                      <Icon :icon="isExpanded(category.category) ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'" class="text-xs mb-6" />
                    </span>
                    <span v-else class="w-4" />
                    <div class="flex flex-col">
                      <p class="capitalize text-sm">{{ category.description || category.category }}</p>
                      <p class="text-[10px] text-n-slate-9 font-normal opacity-0 group-hover:opacity-100 transition-opacity truncate max-w-full">{{ category.category }}</p>
                    </div>
                  </div>
                </th>
                <td class="px-6 py-4 text-n-slate-10 w-[25%] capitalize">
                  {{ formatNumber(category.usage) }}{{ category.usage !== null ? ' ' : '' }}{{ category.unit }}
                </td>
                <td class="px-6 py-4 font-semibold text-n-slate-12 text-right w-[25%]">
                  {{ formatCurrency(category.price) }}
                </td>
              </tr>
              <tr v-if="categories.length === 0">
                <td colspan="3" class="px-6 py-10 text-center text-n-slate-10">
                  {{ $t('TWILIO_REPORTS.TABLE.NO_USAGE') }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>
