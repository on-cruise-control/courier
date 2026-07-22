<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  offer: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['edit']);
const { t } = useI18n();

const formatDate = value => {
  if (!value) return '—';
  return new Intl.DateTimeFormat(undefined, {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
  }).format(new Date(value));
};

const hasDocument = computed(() => !!props.offer?.offer_document);
const hasDocumentText = computed(() => !!props.offer?.offer_document_text);

const handleEdit = () => emit('edit', props.offer);
</script>

<template>
  <div class="w-full">
    <p
      v-if="!offer"
      class="rounded-2xl border border-n-alpha-2 bg-white px-6 py-10 text-center text-sm text-n-slate-11 dark:bg-n-solid-2"
    >
      {{ t('OFFERS_MGMT.SHOW_NOT_FOUND') }}
    </p>
    <div v-else class="flex flex-col w-full gap-4">
      <div
        class="flex flex-col gap-3 rounded-2xl bg-n-alpha-1 px-4 py-3 dark:bg-n-solid-3/40 md:flex-row md:items-center md:justify-between md:gap-4 md:px-6"
      >
        <div class="min-w-0 flex-1">
          <p
            class="text-xl font-semibold break-words text-n-slate-12 md:text-2xl"
          >
            {{ offer.title }}
          </p>
        </div>
        <div class="flex flex-shrink-0 flex-wrap gap-2 md:justify-end">
          <div
            class="flex items-center gap-2 rounded-xl bg-white px-2.5 py-1.5 text-xs text-n-slate-12 shadow-sm dark:bg-n-solid-3"
          >
            <Icon icon="i-lucide-calendar" class="size-3.5 text-n-slate-10" />
            <div>
              <p class="text-[10px] uppercase tracking-wide text-n-slate-9">
                {{ t('OFFERS_MGMT.FORM.START_DATE.LABEL') }}
              </p>
              <p class="font-semibold">{{ formatDate(offer.start_date) }}</p>
            </div>
          </div>
          <div
            class="flex items-center gap-2 rounded-xl bg-white px-2.5 py-1.5 text-xs text-n-slate-12 shadow-sm dark:bg-n-solid-3"
          >
            <Icon icon="i-lucide-flag" class="size-3.5 text-n-slate-10" />
            <div>
              <p class="text-[10px] uppercase tracking-wide text-n-slate-9">
                {{ t('OFFERS_MGMT.FORM.END_DATE.LABEL') }}
              </p>
              <p class="font-semibold">{{ formatDate(offer.end_date) }}</p>
            </div>
          </div>
        </div>
      </div>

      <section
        v-if="hasDocument"
        class="flex items-center justify-between rounded-xl border border-n-gray-5 px-4 py-2.5"
      >
        <h3 class="text-xs uppercase tracking-wide text-n-slate-9">
          {{ t('OFFERS_MGMT.TABLE.PDF') }}
        </h3>
        <a
          :href="offer.offer_document"
          target="_blank"
          rel="noopener noreferrer"
          class="inline-flex items-center gap-2 text-sm text-n-brand hover:underline"
        >
          <i class="i-lucide-file-text size-4" />
          {{ t('OFFERS_MGMT.TABLE.VIEW_DOCUMENT') }}
        </a>
      </section>

      <section
        v-if="hasDocumentText"
        class="rounded-2xl border border-n-gray-5 p-4"
      >
        <h3 class="mb-2 text-xs uppercase tracking-wide text-n-slate-9">
          {{ t('OFFERS_MGMT.TABLE.OFFER_DETAILS') }}
        </h3>
        <div
          class="max-[426px]:h-32 min-[426px]:h-64 overflow-y-auto whitespace-pre-wrap text-sm leading-relaxed text-n-slate-11 [scrollbar-width:thin]"
        >
          {{ offer.offer_document_text }}
        </div>
      </section>

      <div class="flex justify-end">
        <Button icon="i-lucide-pencil" sm type="button" @click="handleEdit">
          {{ t('OFFERS_MGMT.TABLE.EDIT_ACTION') }}
        </Button>
      </div>
    </div>
  </div>
</template>
