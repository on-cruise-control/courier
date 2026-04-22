<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { format, subDays } from 'date-fns';
import { useAlert } from 'dashboard/composables';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import BookingCard from '../components/BookingCard.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import WootDateRangePicker from 'dashboard/components/ui/DateRangePicker.vue';

const store = useStore();
const { t } = useI18n();

const CUSTOM_DATE_RANGE_ID = 5;

const dateRangeOptions = computed(() => [
  { id: 0, name: t('REPORT.DATE_RANGE_OPTIONS.LAST_7_DAYS') },
  { id: 1, name: t('REPORT.DATE_RANGE_OPTIONS.LAST_30_DAYS') },
  { id: 2, name: t('REPORT.DATE_RANGE_OPTIONS.LAST_3_MONTHS') },
  { id: 3, name: t('REPORT.DATE_RANGE_OPTIONS.LAST_6_MONTHS') },
  { id: 4, name: t('REPORT.DATE_RANGE_OPTIONS.LAST_YEAR') },
  { id: 5, name: t('REPORT.DATE_RANGE_OPTIONS.CUSTOM_DATE_RANGE') },
]);

const selectedDateRange = ref({ id: 1, name: t('REPORT.DATE_RANGE_OPTIONS.LAST_30_DAYS') });
const customDateRange = ref([new Date(), new Date()]);
const isCustomDateRange = computed(() => selectedDateRange.value?.id === CUSTOM_DATE_RANGE_ID);

const currentPage = ref(1);
const dateRange = ref({
  start: format(subDays(new Date(), 29), 'yyyy-MM-dd'),
  end: format(new Date(), 'yyyy-MM-dd'),
});

const bookings = computed(() => store.getters['bookings/getRecords']);
const uiFlags = computed(() => store.getters['bookings/getUIFlags']);
const meta = computed(() => store.getters['bookings/getMeta']);

const fetchBookings = async () => {
  try {
    await store.dispatch('bookings/fetch', {
      page: currentPage.value,
      createdAtAfter: dateRange.value.start,
      createdAtBefore: dateRange.value.end,
    });
  } catch (error) {
    useAlert(t('BOOKINGS.ERROR_FETCHING'));
  }
};

onMounted(fetchBookings);

watch(currentPage, fetchBookings);

const applyFilter = () => {
  currentPage.value = 1;
  fetchBookings();
};

const diffMap = { 0: 6, 1: 29, 2: 89, 3: 179, 4: 364 };

const onDateRangeSelect = selected => {
  selectedDateRange.value = selected;
  if (selected.id !== CUSTOM_DATE_RANGE_ID) {
    const diff = diffMap[selected.id] ?? 29;
    dateRange.value = {
      start: format(subDays(new Date(), diff), 'yyyy-MM-dd'),
      end: format(new Date(), 'yyyy-MM-dd'),
    };
    applyFilter();
  }
};

const onCustomDateRangeChange = value => {
  customDateRange.value = value;
  dateRange.value = {
    start: format(value[0], 'yyyy-MM-dd'),
    end: format(value[1], 'yyyy-MM-dd'),
  };
  applyFilter();
};
</script>

<template>
  <div class="flex flex-col flex-1 h-full m-0 overflow-auto bg-n-background">
    <div class="flex flex-col w-full h-full">
      <!-- HEADER -->
      <header class="flex-shrink-0 pt-8 bg-n-background sticky top-0 z-20 px-6">
        <div class="mx-auto max-w-[60rem] flex flex-col gap-6">
          <div class="flex items-center justify-between">
            <h1 class="text-2xl font-semibold text-n-slate-12">
              {{ t('BOOKINGS.LIST_HEADING') }}
            </h1>
          </div>

          <!-- FILTERS -->
          <div class="flex flex-wrap items-end gap-4">
            <div class="multiselect-wrap--small min-w-[180px] bookings-filter-multiselect">
              <p class="mb-2 text-xs font-medium text-n-slate-11">
                <!-- {{ t('BOOKINGS.DATE_RANGE_LABEL') }} -->
              </p>
              <multiselect
                v-model="selectedDateRange"
                track-by="id"
                label="name"
                :placeholder="t('REPORT.CUSTOM_DATE_RANGE.PLACEHOLDER')"
                selected-label=""
                select-label=""
                deselect-label=""
                :options="dateRangeOptions"
                :searchable="false"
                :allow-empty="false"
                @select="onDateRangeSelect"
              />
            </div>
            <div v-if="isCustomDateRange" class="min-w-[220px]">
              <p class="mb-2 text-xs font-medium text-n-slate-11">
                {{ t('REPORT.CUSTOM_DATE_RANGE.PLACEHOLDER') }}
              </p>
              <WootDateRangePicker
                :value="customDateRange"
                :confirm-text="t('REPORT.CUSTOM_DATE_RANGE.CONFIRM')"
                :placeholder="t('REPORT.CUSTOM_DATE_RANGE.PLACEHOLDER')"
                @change="onCustomDateRangeChange"
              />
            </div>
          </div>
        </div>
      </header>

      <!-- CONTENT -->
      <main class="flex-1 overflow-y-auto ltr:pl-6 rtl:pr-6 ltr:pr-6 rtl:pl-6 pt-2">
        <div class="mx-auto max-w-[60rem] pb-8">
          <div v-if="uiFlags.isFetching" class="flex h-64 items-center justify-center">
            <Spinner />
          </div>
          
          <div v-else-if="bookings.length === 0" class="flex h-64 flex-col items-center justify-center text-n-slate-11 bg-n-solid-2 rounded-2xl border border-n-weak/30">
            <div class="i-lucide-calendar-x mb-4 size-10 opacity-20" />
            <p class="text-lg font-medium opacity-50">{{ t('BOOKINGS.EMPTY_MESSAGE') }}</p>
          </div>

          <div v-else class="flex flex-col gap-4">
            <BookingCard
              v-for="booking in bookings"
              :key="booking.id"
              :booking="booking"
            />
          </div>
        </div>
      </main>

      <!-- FOOTER -->
      <footer v-if="meta.count > 0" class="sticky bottom-0 z-10 px-6 pb-6">
        <PaginationFooter
          :current-page="currentPage"
          :total-items="meta.count"
          :items-per-page="10"
          @update:current-page="currentPage = $event"
        />
      </footer>
    </div>
  </div>
</template>

<style scoped lang="scss">
.bookings-filter-multiselect {
  :deep() {
    .multiselect__tags,
    .multiselect__input,
    .multiselect {
      @apply bg-n-alpha-3 !border-n-weak text-n-slate-12 rounded-lg text-sm min-h-[2.5rem];
    }

    .multiselect__tags {
      @apply bg-n-alpha-3 border border-n-weak m-0 min-h-[2.5rem] pt-0;
    }

    .multiselect__single {
      @apply bg-n-alpha-3 text-n-slate-12;
    }

    .multiselect__content-wrapper {
      @apply bg-n-solid-2 border border-n-weak text-n-slate-12;
    }

    .multiselect__select {
      @apply min-h-0;
    }
  }
}
</style>
