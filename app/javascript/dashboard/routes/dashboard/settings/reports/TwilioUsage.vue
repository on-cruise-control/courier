<script>
import { mapGetters } from 'vuex';
import format from 'date-fns/format';
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
      selectedPeriod: 'this_month',
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
    summaryCategories() {
      return this.twilioUsage?.summary_categories || [];
    },
    totalPriceCategory() {
      return this.summaryCategories.find(c => c.category === 'totalprice') || {};
    },
    gatewayChargesCategory() {
      return this.summaryCategories.find(c => c.category === 'stripe') || {};
    },
    grandTotalCategory() {
      return this.summaryCategories.find(c => c.category === 'grand-total') || {};
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
        period: this.selectedPeriod,
      });
    },
    onPeriodChange(event) {
      this.selectedPeriod = event.target.value;
      this.fetchAllData();
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
        maximumFractionDigits: 2,
      }).format(value);
    },
    formatNumber(value) {
      if (value === undefined || value === null) return '';
      return new Intl.NumberFormat('en-US').format(value);
    },
    formatDate(date) {
      if (!date || date === 'N/A') return 'N/A';
      return format(new Date(date), 'MMM d, yyyy');
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4 pb-12">
    <ReportHeader :header-title="$t('TWILIO_REPORTS.HEADER')" />
    
    <div class="px-0 flex flex-col md:flex-row justify-between items-start md:items-center gap-3 mb-2">
      <div class="flex flex-col md:flex-row items-start md:items-center gap-4 w-full">
        <select
          v-model="selectedPeriod"
          class="h-9 w-auto rounded-lg border border-n-weak bg-n-background text-n-slate-12 text-sm px-3 pr-8 cursor-pointer focus:outline-none focus:ring-1 focus:ring-n-brand min-w-[160px] mb-0"
          @change="onPeriodChange"
        >
          <option value="today">{{ $t('TWILIO_REPORTS.PERIODS.TODAY') }}</option>
          <option value="yesterday">{{ $t('TWILIO_REPORTS.PERIODS.YESTERDAY') }}</option>
          <option value="this_month">{{ $t('TWILIO_REPORTS.PERIODS.THIS_MONTH') }}</option>
          <option value="last_month">{{ $t('TWILIO_REPORTS.PERIODS.LAST_MONTH') }}</option>
        </select>

        <div v-if="twilioUsage && !isFetching" class="flex items-center gap-3 px-4 py-1.5 bg-n-solid-2 border border-n-weak rounded-lg shadow-sm">
          <div class="flex flex-col">
            <span class="text-[9px] font-bold uppercase text-n-slate-9 leading-none mb-0.5">{{ $t('TWILIO_REPORTS.METRICS.PERIOD') }}</span>
            <span class="text-xs text-n-slate-12 tabular-nums">
              {{ formatDate(totalUsage.period?.start_date) }} – {{ formatDate(totalUsage.period?.end_date) }}
            </span>
          </div>
        </div>
      </div>
      <div v-if="twilioUsage && !isFetching" class="hidden lg:block">
      </div>
    </div>

    <div v-if="isFetching" class="flex items-center justify-center p-20">
      <woot-loading-state :message="$t('TWILIO_REPORTS.LOADING')" />
    </div>

    <div v-else-if="twilioUsage" class="flex flex-col gap-6">
      <div class="bg-n-solid-2 overflow-hidden border border-n-weak rounded-xl shadow-sm">

        <div class="overflow-x-auto">
          <table class="w-full text-sm text-left text-n-slate-11 table-fixed border-collapse">
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
                      <p v-if="category.simple_desc" class="text-[10px] text-n-slate-9 font-normal opacity-0 group-hover:opacity-100 transition-opacity truncate max-w-full">
                        {{ category.simple_desc }}
                      </p>
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

      <div v-if="summaryCategories.length" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div v-if="totalPriceCategory.category" class="bg-n-solid-2 p-6 rounded-xl border border-n-weak shadow-sm flex flex-col justify-between">
          <p class="text-xs text-n-slate-11 font-semibold uppercase tracking-wider mb-2">Total Price</p>
          <div>
            <p class="text-2xl font-bold text-n-slate-12">{{ formatCurrency(totalPriceCategory.price) }}</p>
            <p class="text-[10px] text-n-slate-9 mt-1 italic">{{ totalPriceCategory.simple_desc }}</p>
          </div>
        </div>

        <div v-if="gatewayChargesCategory.category" class="bg-n-solid-2 p-6 rounded-xl border border-n-weak shadow-sm flex flex-col justify-between">
          <p class="text-xs text-n-slate-11 font-semibold uppercase tracking-wider mb-2">Gateway Charges</p>
          <div>
            <p class="text-2xl font-bold text-n-slate-12">{{ formatCurrency(gatewayChargesCategory.price) }}</p>
            <p class="text-[10px] text-n-slate-9 mt-1 italic">{{ gatewayChargesCategory.simple_desc }}</p>
          </div>
        </div>

        <div v-if="grandTotalCategory.category" class="bg-n-slate-800/40 p-6 rounded-xl border border-n-weak shadow-md flex flex-col justify-between md:col-span-2 lg:col-span-1">
          <p class="text-xs text-n-slate-11 font-semibold uppercase tracking-wider mb-2">Grand Total</p>
          <div>
            <p class="text-3xl font-extrabold text-green-500">{{ formatCurrency(grandTotalCategory.price) }}</p>
            <p class="text-[10px] text-n-teal-11 mt-1 font-medium">{{ grandTotalCategory.simple_desc }}</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
