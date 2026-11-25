<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { getTime } from '../helpers/businessHour';

const props = defineProps({
  inbox: { type: Object, default: () => ({}) },
});

const { t } = useI18n();
const store = useStore();
const isSyncing = ref(false);

const DAY_NAMES = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const formatTime = value => {
  const [hour, minute] = value.split(':').map(Number);
  return getTime(hour, minute);
};

const totalHours = ({ open, close }) => {
  const [openHour, openMinute] = open.split(':').map(Number);
  const [closeHour, closeMinute] = close.split(':').map(Number);
  const minutes =
    (closeHour || 24) * 60 + closeMinute - (openHour * 60 + openMinute);
  const [h, m] = [Math.floor(minutes / 60), minutes % 60];
  return [h && `${h}h`, m && `${m}m`].filter(Boolean).join(' ');
};

const serviceHours = computed(() => props.inbox.service_hours);

const days = computed(() =>
  DAY_NAMES.map((name, index) => {
    const slot = serviceHours.value?.schedule?.[index];
    return {
      name,
      from: slot && formatTime(slot.open),
      to: slot && formatTime(slot.close),
      total: slot && totalHours(slot),
    };
  })
);

const syncServiceHours = async () => {
  isSyncing.value = true;
  try {
    await store.dispatch('inboxes/syncServiceHours', props.inbox.id);
    useAlert(t('INBOX_MGMT.SERVICE_HOURS.SYNC_SUCCESS'));
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('INBOX_MGMT.SERVICE_HOURS.SYNC_ERROR')
    );
  } finally {
    isSyncing.value = false;
  }
};
</script>

<template>
  <div class="mx-6">
    <p
      v-if="!serviceHours"
      class="mb-4 text-body-main font-medium text-n-ruby-9"
    >
      {{ t('INBOX_MGMT.SERVICE_HOURS.NOT_SYNCED') }}
    </p>

    <div class="flex items-center justify-between gap-4 mb-4">
      <p class="mb-0 min-w-0 flex-1 text-body-main text-n-slate-11">
        {{ t('INBOX_MGMT.SERVICE_HOURS.DESCRIPTION') }}
      </p>
      <NextButton
        class="shrink-0 whitespace-nowrap"
        :label="t('INBOX_MGMT.SERVICE_HOURS.SYNC')"
        :is-loading="isSyncing"
        @click="syncServiceHours"
      />
    </div>

    <div v-if="serviceHours" class="flex items-center gap-4 mb-4">
      <span class="text-body-main font-medium text-n-slate-12">
        {{ t('INBOX_MGMT.SERVICE_HOURS.TIMEZONE_LABEL') }}
      </span>
      <span class="text-body-main text-n-slate-11">
        {{ serviceHours.timezone }}
      </span>
    </div>

    <table
      class="min-w-full table-auto outline outline-1 -outline-offset-1 outline-n-weak rounded-xl"
    >
      <thead>
        <tr class="border-b border-n-weak">
          <th class="py-3 ltr:pl-4 text-start text-heading-3 text-n-slate-12">
            {{ t('INBOX_MGMT.BUSINESS_HOURS.DAY.DAY') }}
          </th>
          <th class="py-3 text-start text-heading-3 text-n-slate-12">
            {{ t('INBOX_MGMT.BUSINESS_HOURS.DAY.AVAILABILITY') }}
          </th>
          <th class="py-3 text-start text-heading-3 text-n-slate-12">
            {{ t('INBOX_MGMT.BUSINESS_HOURS.DAY.HOURS') }}
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-n-weak">
        <tr v-for="day in days" :key="day.name">
          <td class="py-4 ltr:pl-4 text-body-main font-medium text-n-slate-12">
            {{ day.name }}
          </td>
          <td class="py-4 text-body-main text-n-slate-11">
            <template v-if="day.from">{{ day.from }} – {{ day.to }}</template>
            <template v-else>
              {{ t('INBOX_MGMT.BUSINESS_HOURS.DAY.UNAVAILABLE') }}
            </template>
          </td>
          <td class="py-4">
            <span
              v-if="day.total"
              class="bg-n-blue-3 text-n-blue-11 text-label-small inline-block px-2 py-1 rounded-lg whitespace-nowrap"
            >
              {{ day.total }}
            </span>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
