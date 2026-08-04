<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { format, subDays } from 'date-fns';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import BookingCard from '../components/BookingCard.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';

const store = useStore();
const { t } = useI18n();

const currentPage = ref(1);
const isDownloading = ref(false);

const customDateRange = ref([subDays(new Date(), 29), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_30_DAYS);
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
  } catch {
    useAlert(t('BOOKINGS.ERROR_FETCHING'));
  }
};

const downloadBookings = async () => {
  isDownloading.value = true;
  try {
    await store.dispatch('bookings/download', {
      createdAtAfter: dateRange.value.start,
      createdAtBefore: dateRange.value.end,
      fileName: `bookings-${dateRange.value.start}-to-${dateRange.value.end}.csv`,
    });
  } catch {
    useAlert(t('BOOKINGS.DOWNLOAD_FAILED'));
  } finally {
    isDownloading.value = false;
  }
};

const onDateRangeChange = value => {
  const [startDate, endDate, rangeType] = value;
  customDateRange.value = [startDate, endDate];
  selectedDateRange.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  dateRange.value = {
    start: format(startDate, 'yyyy-MM-dd'),
    end: format(endDate, 'yyyy-MM-dd'),
  };
  currentPage.value = 1;
  fetchBookings();
};

const onPageChange = page => {
  currentPage.value = page;
  fetchBookings();
};

onMounted(fetchBookings);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <!-- HEADER -->
    <header class="flex-shrink-0 bg-n-surface-1 px-6 py-5">
      <div class="mx-auto max-w-[60rem] flex items-center justify-between gap-6">
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('BOOKINGS.LIST_HEADING') }}
        </h1>
        <Button
          :label="t('BOOKINGS.DOWNLOAD')"
          icon="i-lucide-download"
          size="sm"
          :is-loading="isDownloading"
          @click="downloadBookings"
        />
      </div>
      <div class="mx-auto max-w-[60rem] mt-3">
        <WootDatePicker
          v-model:date-range="customDateRange"
          v-model:range-type="selectedDateRange"
          @date-range-changed="onDateRangeChange"
        />
      </div>
    </header>

    <!-- CONTENT -->
    <main class="flex-1 overflow-y-auto py-5 px-6">
      <div class="mx-auto max-w-[60rem]">
        <div v-if="uiFlags.isFetching" class="flex h-64 items-center justify-center">
          <Spinner />
        </div>
        <div
          v-else-if="bookings.length === 0"
          class="flex h-64 flex-col items-center justify-center rounded-2xl border border-n-weak bg-n-solid-1 text-n-slate-11"
        >
          <div class="i-lucide-calendar-x mb-4 size-10 opacity-30" />
          <p class="text-base font-medium opacity-60">
            {{ t('BOOKINGS.EMPTY_MESSAGE') }}
          </p>
        </div>
        <div v-else class="flex flex-col gap-3 pb-4">
          <BookingCard
            v-for="booking in bookings"
            :key="booking.id"
            :booking="booking"
          />
        </div>
      </div>
    </main>

    <!-- PAGINATION -->
    <footer
      v-if="meta.count > 0"
      class="flex-shrink-0 bg-n-surface-1 px-6 py-3"
    >
      <div class="mx-auto max-w-[60rem]">
        <PaginationFooter
          :current-page="currentPage"
          :total-items="meta.count"
          :items-per-page="10"
          @update:current-page="onPageChange"
        />
      </div>
    </footer>
  </div>
</template>
