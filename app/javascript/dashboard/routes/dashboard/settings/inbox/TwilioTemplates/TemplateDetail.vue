<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  template: { type: Object, required: true },
});

const emit = defineEmits(['back', 'delete', 'duplicate', 'submitApproval']);

const { t } = useI18n();

const STATUS_CONFIG = {
  approved: { dot: 'bg-green-500', label: 'text-green-700' },
  pending: { dot: 'bg-yellow-400', label: 'text-yellow-700' },
  rejected: { dot: 'bg-ruby-500', label: 'text-ruby-700' },
  unsubmitted: { dot: 'bg-n-slate-5', label: 'text-n-slate-9' },
};

function statusConfig(status) {
  return STATUS_CONFIG[status] || STATUS_CONFIG.unsubmitted;
}

function typeLabel(type) {
  return (type || 'text')
    .replace(/_/g, ' ')
    .replace(/\b\w/g, c => c.toUpperCase());
}

function formatDate(dateStr) {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
}

const variableKeys = computed(() => {
  const vars = props.template.variables;
  if (!vars || typeof vars !== 'object') return [];
  return Object.keys(vars);
});

function varLabel(key) {
  return `{{${key}}}`;
}

function charCount(str) {
  return t('TWILIO_TEMPLATES.DETAIL.CHAR_COUNT', { count: str.length });
}

const types = computed(() => props.template.types || {});

const listButton = computed(() => types.value['twilio/list-picker']?.button || '');
const listItems = computed(() => types.value['twilio/list-picker']?.items || []);

const quickReplyButtons = computed(() => types.value['twilio/quick-reply']?.actions || []);

const mediaUrl = computed(
  () => types.value['twilio/media']?.media?.[0] || types.value['twilio/card']?.media?.[0] || ''
);
const cardTitle = computed(() => types.value['twilio/card']?.title || '');

const ctaActions = computed(() => types.value['twilio/call-to-action']?.actions || []);

function languageName(code) {
  if (!code) return 'en';
  try {
    return new Intl.DisplayNames(['en'], { type: 'language' }).of(code) || code;
  } catch {
    return code;
  }
}
</script>

<template>
  <div class="flex flex-col gap-5 py-5">
    <div>
      <button
        class="flex items-center gap-1.5 text-sm text-n-slate-9 hover:text-n-slate-12 transition-colors mb-3 w-fit"
        @click="emit('back')"
      >
        <Icon icon="i-lucide-arrow-left" class="size-4" />
        {{ t('TWILIO_TEMPLATES.DETAIL.BACK') }}
      </button>
      <h2 class="text-xl font-bold text-n-slate-12 font-mono">
        {{ template.friendly_name }}
      </h2>
    </div>

    <!-- General Information -->
    <div class="border border-n-slate-3 rounded-xl overflow-hidden">
      <div class="px-5 py-3.5 bg-n-slate-3">
        <span class="text-sm font-semibold text-n-slate-12">
          {{ t('TWILIO_TEMPLATES.DETAIL.GENERAL_INFO') }}
        </span>
      </div>

      <div class="px-5 py-5 grid grid-cols-1 sm:grid-cols-3 gap-x-8 gap-y-5 border-t border-n-slate-4">
        <div>
          <p class="text-xs font-medium text-n-slate-9 mb-1">
            {{ t('TWILIO_TEMPLATES.DETAIL.TEMPLATE_NAME') }}
          </p>
          <p class="text-sm text-n-slate-12">{{ template.friendly_name }}</p>
        </div>
        <div>
          <p class="text-xs font-medium text-n-slate-9 mb-1">
            {{ t('TWILIO_TEMPLATES.DETAIL.CONTENT_SID') }}
          </p>
          <p class="text-sm text-n-slate-12 font-mono break-all">
            {{ template.content_sid }}
          </p>
        </div>
        <div>
          <p class="text-xs font-medium text-n-slate-9 mb-1">
            {{ t('TWILIO_TEMPLATES.DETAIL.LANGUAGE') }}
          </p>
          <p class="text-sm text-n-slate-12">{{ languageName(template.language) }}</p>
        </div>
        <div>
          <p class="text-xs font-medium text-n-slate-9 mb-1">
            {{ t('TWILIO_TEMPLATES.DETAIL.APPROVAL_STATUS') }}
          </p>
          <span
            class="inline-flex items-center gap-1.5 text-sm font-medium capitalize"
            :class="statusConfig(template.status).label"
          >
            <span
              class="size-2 rounded-full"
              :class="statusConfig(template.status).dot"
            />
            {{ !template.status || template.status === 'unsubmitted' ? 'Not Submitted' : template.status }}
          </span>
        </div>
        <div>
          <p class="text-xs font-medium text-n-slate-9 mb-1">
            {{ t('TWILIO_TEMPLATES.DETAIL.CONTENT_TYPE') }}
          </p>
          <p class="text-sm text-n-slate-12">
            {{ typeLabel(template.template_type) }}
          </p>
        </div>
        <div>
          <p class="text-xs font-medium text-n-slate-9 mb-1">
            {{ t('TWILIO_TEMPLATES.DETAIL.LAST_UPDATED') }}
          </p>
          <p class="text-sm text-n-slate-12">
            {{ formatDate(template.updated_at) }}
          </p>
        </div>
        <div v-if="template.category">
          <p class="text-xs font-medium text-n-slate-9 mb-1">
            {{ t('TWILIO_TEMPLATES.DETAIL.CATEGORY') }}
          </p>
          <p class="text-sm text-n-slate-12 capitalize">
            {{ template.category }}
          </p>
        </div>
      </div>
    </div>

    <!-- Content -->
    <div class="border border-n-slate-3 rounded-xl overflow-hidden">
      <div class="px-5 py-3.5 bg-n-slate-3">
        <span class="text-sm font-semibold text-n-slate-12">
          {{ t('TWILIO_TEMPLATES.DETAIL.CONTENT') }}
        </span>
      </div>

      <div class="px-5 py-5 border-t border-n-slate-4 flex flex-col gap-4">
        <div class="inline-flex w-full">
          <span
            class="px-4 py-2 text-sm font-medium text-[#182933] border-b-2 border-[#182933] -mb-px"
          >
            {{ typeLabel(template.template_type) }}
          </span>
        </div>

        <p class="text-sm font-medium text-n-slate-11">
          {{ t('TWILIO_TEMPLATES.DETAIL.CONFIGURE_CONTENT') }}
          {{ typeLabel(template.template_type) }}
        </p>

        <div class="flex flex-col gap-4">
          <div>
            <p class="text-xs font-medium text-n-slate-11 mb-1.5">
              {{ t('TWILIO_TEMPLATES.FORM.BODY') }}
            </p>
            <div
              class="bg-n-slate-1 border border-n-slate-4 bg-n-slate-2 rounded-lg px-4 py-3 text-sm text-n-slate-12 whitespace-pre-wrap leading-relaxed min-h-[80px]"
            >
              {{ template.body || t('TWILIO_TEMPLATES.DETAIL.NO_BODY') }}
            </div>
            <p
              v-if="template.body"
              class="text-xs text-n-slate-8 mt-1 text-right"
            >
              {{ charCount(template.body) }}
            </p>
          </div>

          <div v-if="variableKeys.length > 0">
            <p class="text-xs font-medium text-n-slate-11 mb-1.5">
              {{ t('TWILIO_TEMPLATES.DETAIL.VARIABLES') }}
            </p>
            <div class="flex flex-wrap gap-2">
              <span
                v-for="key in variableKeys"
                :key="key"
                class="inline-flex items-center text-xs px-2.5 py-1 bg-n-slate-3 text-n-slate-12 rounded-md font-mono"
              >
                {{ varLabel(key) }}
              </span>
            </div>
          </div>

          <!-- Media URL -->
          <div v-if="mediaUrl">
            <p class="text-xs font-medium text-n-slate-11 mb-1.5">
              {{ t('TWILIO_TEMPLATES.FORM.MEDIA_URL') }}
            </p>
            <a
              :href="mediaUrl"
              target="_blank"
              rel="noopener noreferrer"
              class="text-sm text-[#182933] underline break-all"
            >
              {{ mediaUrl }}
            </a>
          </div>

          <!-- Card Title -->
          <div v-if="cardTitle">
            <p class="text-xs font-medium text-n-slate-11 mb-1.5">
              {{ t('TWILIO_TEMPLATES.FORM.CARD_TITLE') }}
            </p>
            <p class="text-sm text-n-slate-12">{{ cardTitle }}</p>
          </div>

          <!-- Quick Reply Buttons -->
          <div v-if="quickReplyButtons.length > 0">
            <p class="text-xs font-medium text-n-slate-11 mb-1.5">
              {{ t('TWILIO_TEMPLATES.FORM.BUTTONS') }}
            </p>
            <div class="flex flex-col gap-3">
              <div
                v-for="(btn, idx) in quickReplyButtons"
                :key="idx"
                class="flex flex-col gap-2 p-3 border border-n-slate-4 rounded-lg bg-n-slate-2"
              >
                <p class="text-xs font-medium text-n-slate-10">Button {{ idx + 1 }}</p>
                <div class="flex flex-col gap-1">
                  <p class="text-xs text-n-slate-9">{{ t('TWILIO_TEMPLATES.FORM.BUTTON_TITLE') }}</p>
                  <div class="flex items-center justify-between border border-n-slate-4 rounded px-3 py-2 bg-n-slate-1">
                    <p class="text-sm text-n-slate-12">{{ btn.title }}</p>
                    <span class="text-xs text-n-slate-8 shrink-0 ml-2">{{ btn.title?.length || 0 }}/20</span>
                  </div>
                </div>
                <div v-if="btn.id" class="flex flex-col gap-1">
                  <p class="text-xs text-n-slate-9">{{ t('TWILIO_TEMPLATES.FORM.BUTTON_ID') }}</p>
                  <div class="flex items-center justify-between border border-n-slate-4 rounded px-3 py-2 bg-n-slate-1">
                    <p class="text-sm text-n-slate-12 font-mono">{{ btn.id }}</p>
                    <span class="text-xs text-n-slate-8 shrink-0 ml-2">{{ btn.id?.length || 0 }}/200</span>
                  </div>
                  <p class="text-xs text-n-slate-8">{{ t('TWILIO_TEMPLATES.FORM.BUTTON_ID_HINT') }}</p>
                </div>
              </div>
            </div>
          </div>

          <!-- CTA Actions -->
          <div v-if="ctaActions.length > 0">
            <p class="text-xs font-medium text-n-slate-11 mb-1.5">
              {{ t('TWILIO_TEMPLATES.FORM.ACTIONS') }}
            </p>
            <div class="flex flex-col gap-2">
              <div
                v-for="(action, idx) in ctaActions"
                :key="idx"
                class="flex flex-col gap-1 p-3 border border-n-slate-4 rounded-lg bg-n-slate-2"
              >
                <div class="flex items-center gap-2">
                  <span class="text-xs px-2 py-0.5 bg-n-slate-3 text-n-slate-10 rounded font-medium">
                    {{ action.type === 'PHONE_NUMBER' ? t('TWILIO_TEMPLATES.FORM.ACTION_TYPE_PHONE') : t('TWILIO_TEMPLATES.FORM.ACTION_TYPE_URL') }}
                  </span>
                  <p class="text-sm text-n-slate-12 font-medium">{{ action.title }}</p>
                </div>
                <p v-if="action.url" class="text-sm text-[#182933] break-all">{{ action.url }}</p>
                <p v-if="action.phone" class="text-sm text-n-slate-12">{{ action.phone }}</p>
              </div>
            </div>
          </div>

          <div v-if="listButton">
            <p class="text-xs font-medium text-n-slate-11 mb-1.5">
              {{ t('TWILIO_TEMPLATES.FORM.LIST_BUTTON') }}
            </p>
            <div class="flex items-center justify-between p-3 border border-n-slate-4 rounded-lg bg-n-slate-2">
              <p class="text-sm text-n-slate-12">{{ listButton }}</p>
              <span class="text-xs text-n-slate-8">{{ listButton.length }}/20</span>
            </div>
          </div>

          <div v-if="listItems.length > 0">
            <p class="text-xs font-medium text-n-slate-11 mb-1.5">
              {{ t('TWILIO_TEMPLATES.FORM.LIST_ITEMS') }}
            </p>
            <div class="flex flex-col gap-3">
              <div
                v-for="(item, idx) in listItems"
                :key="idx"
                class="flex flex-col gap-2 p-3 border border-n-slate-4 rounded-lg bg-n-slate-2"
              >
                <p class="text-xs font-medium text-n-slate-10">{{ idx + 1 }}.</p>
                <div class="flex flex-col gap-1">
                  <p class="text-xs text-n-slate-9">{{ t('TWILIO_TEMPLATES.FORM.LIST_ITEM_TITLE') }}</p>
                  <div class="flex items-center justify-between border border-n-slate-4 rounded px-3 py-2 bg-n-slate-1">
                    <p class="text-sm text-n-slate-12">{{ item.item || item.title }}</p>
                    <span class="text-xs text-n-slate-8 shrink-0 ml-2">{{ (item.item || item.title)?.length || 0 }}/24</span>
                  </div>
                </div>
                <div class="flex flex-col gap-1">
                  <p class="text-xs text-n-slate-9">{{ t('TWILIO_TEMPLATES.FORM.LIST_ITEM_ID') }}</p>
                  <div class="flex items-center justify-between border border-n-slate-4 rounded px-3 py-2 bg-n-slate-1">
                    <p class="text-sm text-n-slate-12 font-mono">{{ item.id }}</p>
                    <span class="text-xs text-n-slate-8 shrink-0 ml-2">{{ item.id?.length || 0 }}/200</span>
                  </div>
                </div>
                <div class="flex flex-col gap-1">
                  <p class="text-xs text-n-slate-9">{{ t('TWILIO_TEMPLATES.FORM.LIST_ITEM_DESC') }}</p>
                  <div class="flex items-center justify-between border border-n-slate-4 rounded px-3 py-2 bg-n-slate-1">
                    <p class="text-sm text-n-slate-12">{{ item.description || '' }}</p>
                    <span class="text-xs text-n-slate-8 shrink-0 ml-2">{{ item.description?.length || 0 }}/72</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="sticky bottom-0 flex flex-wrap items-center gap-2 px-1 py-3 bg-n-slate-1 border-t border-n-slate-3">
      <button
        v-if="template.status !== 'approved' && template.status !== 'pending'"
        class="px-4 py-2 text-sm font-medium bg-[#182933] hover:bg-[#182933]/90 text-white border border-[#182933] rounded-lg transition-colors"
        @click="emit('submitApproval', template)"
      >
        {{ t('TWILIO_TEMPLATES.LIST.SUBMIT_APPROVAL') }}
      </button>
      <button
        class="px-4 py-2 text-sm font-medium bg-n-slate-4 hover:bg-n-slate-3 text-n-slate-11 border border-n-slate-11 rounded-lg transition-colors"
        @click="emit('duplicate', template)"
      >
        {{ t('TWILIO_TEMPLATES.DETAIL.DUPLICATE') }}
      </button>
      <button
        class="px-4 py-2 text-sm font-medium text-white bg-red-500 hover:bg-red-400 border border-ruby-200 rounded-lg transition-colors ml-auto"
        @click="emit('delete', template)"
      >
        {{ t('TWILIO_TEMPLATES.DETAIL.DELETE') }}
      </button>
    </div>
  </div>
</template>
