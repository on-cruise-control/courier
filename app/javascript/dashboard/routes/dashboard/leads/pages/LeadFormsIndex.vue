<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useEmitter } from 'dashboard/composables/emitter';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import FacebookLeadsAPI from 'dashboard/api/facebookLeads';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import LeadsLayout from '../components/LeadsLayout.vue';
import LeadFormCard from '../components/LeadFormCard.vue';

const FORMS_PER_PAGE = 10;
const ALL = 'all';
const DAY_MS = 24 * 60 * 60 * 1000;
// Filter by the form's creation date on Facebook; values are days back
const DATE_RANGES = ['7', '30', '90', '180', '365', ALL];
const DEFAULT_DATE_RANGE = '30';

const { t } = useI18n();
const router = useRouter();

const pages = ref([]);
const selectedInboxId = ref(ALL);
const selectedDateRange = ref(DEFAULT_DATE_RANGE);
const expandedFormId = ref(null);
const currentPage = ref(1);
const isFetching = ref(false);
const isSyncing = ref(false);

const pageOptions = computed(() => [
  { label: t('FACEBOOK_LEADS.FILTERS.ALL_PAGES'), value: ALL },
  ...pages.value.map(page => ({
    label: page.page_name,
    value: String(page.inbox_id),
  })),
]);
const selectedPageLabel = computed(
  () => pageOptions.value.find(o => o.value === selectedInboxId.value)?.label
);

const dateRangeOptions = computed(() =>
  DATE_RANGES.map(value => ({
    label: t(`FACEBOOK_LEADS.FILTERS.DATE_RANGES.${value.toUpperCase()}`),
    value,
  }))
);
const selectedDateRangeLabel = computed(
  () =>
    dateRangeOptions.value.find(o => o.value === selectedDateRange.value)?.label
);

const isInDateRange = form => {
  if (selectedDateRange.value === ALL) return true;
  const since = Date.now() - Number(selectedDateRange.value) * DAY_MS;
  return new Date(form.form_created_at).getTime() >= since;
};

const pageForms = computed(() =>
  pages.value
    .filter(
      page =>
        selectedInboxId.value === ALL ||
        String(page.inbox_id) === selectedInboxId.value
    )
    .flatMap(page => page.forms.map(form => ({ ...form, page })))
);
const forms = computed(() =>
  pageForms.value
    .filter(isInDateRange)
    .sort((a, b) => new Date(b.form_created_at) - new Date(a.form_created_at))
);
const paginatedForms = computed(() =>
  forms.value.slice(
    (currentPage.value - 1) * FORMS_PER_PAGE,
    currentPage.value * FORMS_PER_PAGE
  )
);
watch([selectedInboxId, selectedDateRange], () => {
  currentPage.value = 1;
});
// Forms exist but the date range hides them all
const isFilteredOut = computed(
  () => !forms.value.length && pageForms.value.length > 0
);

const fetchPages = async () => {
  isFetching.value = true;
  try {
    const { data } = await FacebookLeadsAPI.getPages();
    pages.value = data.pages;
  } catch (error) {
    useAlert(t('FACEBOOK_LEADS.FETCH_ERROR'));
  } finally {
    isFetching.value = false;
  }
};

const syncForms = async () => {
  isSyncing.value = true;
  try {
    await FacebookLeadsAPI.sync(
      selectedInboxId.value === ALL ? undefined : selectedInboxId.value
    );
    useAlert(t('FACEBOOK_LEADS.SYNC_STARTED'));
  } catch (error) {
    useAlert(t('FACEBOOK_LEADS.SYNC_ERROR'));
  } finally {
    isSyncing.value = false;
  }
};

const toggleExpanded = id => {
  expandedFormId.value = expandedFormId.value === id ? null : id;
};

const openForm = form => {
  router.push({
    name: 'facebook_form_leads_index',
    params: { formId: form.id },
  });
};

onMounted(fetchPages);
useEmitter(BUS_EVENTS.FACEBOOK_LEAD_CREATED, fetchPages);
</script>

<template>
  <LeadsLayout :header-title="t('FACEBOOK_LEADS.FORMS.HEADING')">
    <template #actions>
      <SelectMenu
        :model-value="selectedInboxId"
        :options="pageOptions"
        :label="selectedPageLabel"
        sub-menu-position="bottom"
        @update:model-value="selectedInboxId = $event"
      />
      <SelectMenu
        :model-value="selectedDateRange"
        :options="dateRangeOptions"
        :label="selectedDateRangeLabel"
        sub-menu-position="bottom"
        @update:model-value="selectedDateRange = $event"
      />
      <div class="w-px h-4 bg-n-strong" />
      <Button
        icon="i-lucide-refresh-cw"
        size="sm"
        :label="t('FACEBOOK_LEADS.SYNC')"
        :is-loading="isSyncing"
        @click="syncForms"
      />
    </template>

    <div
      v-if="isFetching && !pages.length"
      class="flex items-center justify-center py-20"
    >
      <Spinner />
    </div>
    <div
      v-else-if="!forms.length"
      class="flex flex-col items-center gap-2 py-20 text-center"
    >
      <span class="i-lucide-file-text size-8 text-n-slate-10" />
      <p class="text-base font-medium text-n-slate-12">
        {{ t('FACEBOOK_LEADS.FORMS.EMPTY_TITLE') }}
      </p>
      <p class="max-w-md text-sm text-n-slate-11">
        {{
          isFilteredOut
            ? t('FACEBOOK_LEADS.FORMS.EMPTY_IN_RANGE')
            : t('FACEBOOK_LEADS.FORMS.EMPTY_DESCRIPTION')
        }}
      </p>
    </div>
    <div v-else class="flex flex-col gap-4">
      <LeadFormCard
        v-for="form in paginatedForms"
        :key="form.id"
        :form="form"
        :page-name="form.page.page_name"
        :is-expanded="expandedFormId === form.id"
        @toggle="toggleExpanded(form.id)"
        @open="openForm(form)"
      />
    </div>

    <template #footer>
      <PaginationFooter
        v-if="forms.length"
        current-page-info="FACEBOOK_LEADS.PAGINATION_FOOTER.FORMS_SHOWING"
        :current-page="currentPage"
        :total-items="forms.length"
        :items-per-page="FORMS_PER_PAGE"
        class="max-w-[67rem]"
        @update:current-page="currentPage = $event"
      />
    </template>
  </LeadsLayout>
</template>
