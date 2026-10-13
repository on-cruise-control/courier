<script setup>
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import { useEmitter } from 'dashboard/composables/emitter';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import FacebookLeadsAPI from 'dashboard/api/facebookLeads';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import LeadCard from '../components/LeadCard.vue';
import LeadsLayout from '../components/LeadsLayout.vue';

const LEADS_PER_PAGE = 15;

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const page = ref(null);
const form = ref(null);
const leads = ref([]);
const totalLeads = ref(0);
const currentPage = ref(1);
const searchQuery = ref('');
const expandedLeadId = ref(null);
const isFetching = ref(false);
const isSyncing = ref(false);

const fetchLeads = async (pageNumber = 1) => {
  isFetching.value = true;
  try {
    const { data } = await FacebookLeadsAPI.getLeads({
      formId: route.params.formId,
      q: searchQuery.value || undefined,
      page: pageNumber,
    });
    leads.value = data.payload;
    totalLeads.value = data.meta.count;
    currentPage.value = pageNumber;
  } catch (error) {
    useAlert(t('FACEBOOK_LEADS.FETCH_ERROR'));
  } finally {
    isFetching.value = false;
  }
};

// Form details (name, questions, page) come from the pages listing
const fetchForm = async () => {
  try {
    const { data } = await FacebookLeadsAPI.getPages();
    data.pages.forEach(p => {
      const match = p.forms.find(f => String(f.id) === route.params.formId);
      if (match) {
        page.value = p;
        form.value = match;
      }
    });
  } catch (error) {
    useAlert(t('FACEBOOK_LEADS.FETCH_ERROR'));
  }
};

const goToForms = () => router.push({ name: 'facebook_lead_forms_index' });

const debouncedSearch = useDebounceFn(() => fetchLeads(1), 300);
const onSearch = value => {
  searchQuery.value = value;
  debouncedSearch();
};

const toggleExpanded = id => {
  expandedLeadId.value = expandedLeadId.value === id ? null : id;
};

const syncLeads = async () => {
  isSyncing.value = true;
  try {
    await FacebookLeadsAPI.sync(page.value?.inbox_id);
    useAlert(t('FACEBOOK_LEADS.SYNC_STARTED'));
  } catch (error) {
    useAlert(t('FACEBOOK_LEADS.SYNC_ERROR'));
  } finally {
    isSyncing.value = false;
  }
};

useEmitter(BUS_EVENTS.FACEBOOK_LEAD_CREATED, data => {
  if (data.form_id && String(data.form_id) !== route.params.formId) return;
  fetchForm();
  fetchLeads(currentPage.value);
});

onMounted(() => {
  fetchForm();
  fetchLeads(1);
});
</script>

<template>
  <LeadsLayout>
    <template #title>
      <div class="flex items-center gap-3">
        <Button
          variant="link"
          color="slate"
          class="hover:!no-underline focus-visible:!no-underline"
          icon="i-lucide-arrow-left"
          :label="t('FACEBOOK_LEADS.BACK_TO_FORMS')"
          @click="goToForms"
        />
        <div class="w-px h-4 bg-n-strong" />
        <span class="text-lg font-medium truncate text-n-slate-12">
          {{ form?.name }}
        </span>
      </div>
    </template>
    <template #actions>
      <Input
        :model-value="searchQuery"
        type="search"
        :placeholder="t('FACEBOOK_LEADS.SEARCH_PLACEHOLDER')"
        :custom-input-class="[
          'h-8 [&:not(.focus)]:!border-transparent bg-n-alpha-2 dark:bg-n-solid-1 ltr:!pl-8 !py-1 rtl:!pr-8',
        ]"
        class="w-full sm:w-56"
        @input="onSearch($event.target.value)"
      >
        <template #prefix>
          <Icon
            icon="i-lucide-search"
            class="absolute -translate-y-1/2 text-n-slate-11 size-4 top-1/2 ltr:left-2 rtl:right-2"
          />
        </template>
      </Input>
      <div class="w-px h-4 bg-n-strong" />
      <Button
        icon="i-lucide-refresh-cw"
        size="sm"
        :label="t('FACEBOOK_LEADS.SYNC')"
        :is-loading="isSyncing"
        @click="syncLeads"
      />
    </template>

    <div
      v-if="form"
      class="flex flex-wrap items-center gap-x-3 gap-y-1 pb-4 text-sm text-n-slate-11"
    >
      <span class="inline-flex items-center gap-1">
        <span class="i-lucide-facebook size-3.5 text-n-slate-10" />
        {{ page.page_name }}
      </span>
      <div class="w-px h-3 bg-n-slate-6" />
      <span>{{ form.status }}</span>
      <div class="w-px h-3 bg-n-slate-6" />
      <span>
        {{ t('FACEBOOK_LEADS.FORMS.LEADS_COUNT', { count: totalLeads }) }}
      </span>
    </div>

    <div
      v-if="isFetching && !leads.length"
      class="flex items-center justify-center py-20"
    >
      <Spinner />
    </div>
    <div
      v-else-if="!leads.length"
      class="flex flex-col items-center gap-2 py-20 text-center"
    >
      <span class="i-lucide-clipboard-list size-8 text-n-slate-10" />
      <p class="text-base font-medium text-n-slate-12">
        {{ t('FACEBOOK_LEADS.EMPTY.TITLE') }}
      </p>
      <p class="max-w-md text-sm text-n-slate-11">
        {{
          searchQuery
            ? t('FACEBOOK_LEADS.EMPTY.NO_RESULTS')
            : t('FACEBOOK_LEADS.EMPTY.DESCRIPTION')
        }}
      </p>
    </div>
    <div v-else class="flex flex-col gap-4">
      <LeadCard
        v-for="lead in leads"
        :key="lead.id"
        :lead="lead"
        :questions="form?.questions || []"
        :is-expanded="expandedLeadId === lead.id"
        @toggle="toggleExpanded(lead.id)"
      />
    </div>

    <template #footer>
      <PaginationFooter
        v-if="totalLeads > LEADS_PER_PAGE"
        current-page-info="FACEBOOK_LEADS.PAGINATION_FOOTER.SHOWING"
        :current-page="currentPage"
        :total-items="totalLeads"
        :items-per-page="LEADS_PER_PAGE"
        class="max-w-[67rem]"
        @update:current-page="fetchLeads"
      />
    </template>
  </LeadsLayout>
</template>
