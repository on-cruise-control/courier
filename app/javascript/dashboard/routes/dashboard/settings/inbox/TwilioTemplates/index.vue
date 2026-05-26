<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useEmitter } from 'dashboard/composables/emitter';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import twilioTemplatesApi from 'dashboard/api/twilioTemplates';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TemplateModal from './TemplateModal.vue';
import SubmitApprovalModal from './SubmitApprovalModal.vue';
import TemplateDetail from './TemplateDetail.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  inbox: { type: Object, required: true },
});

const { t } = useI18n();

const templates = ref([]);
const isLoading = ref(false);
const isSyncing = ref(false);
const showTemplateModal = ref(false);
const showApprovalModal = ref(false);
const editingTemplate = ref(null);
const prefillTemplate = ref(null);
const approvalTarget = ref(null);
const viewingTemplate = ref(null);
const deleteTarget = ref(null);
const deleteDialogRef = ref(null);
const activeTab = ref('all');
const tabsScrollRef = ref(null);
const canScrollLeft = ref(false);
const canScrollRight = ref(false);

function updateScrollState() {
  const el = tabsScrollRef.value;
  if (!el) return;
  canScrollLeft.value = el.scrollLeft > 0;
  canScrollRight.value = el.scrollLeft + el.clientWidth < el.scrollWidth - 1;
}

function scrollTabs(dir) {
  const el = tabsScrollRef.value;
  if (!el) return;
  el.scrollBy({ left: dir * 120, behavior: 'smooth' });
}

const TABS = [
  { key: 'all', label: 'All' },
  { key: 'approved', label: 'Approved' },
  { key: 'pending', label: 'Pending' },
  { key: 'rejected', label: 'Rejected' },
  { key: 'unsubmitted', label: 'Not Submitted' },
];

const filteredTemplates = computed(() => {
  if (activeTab.value === 'all') return templates.value;
  return templates.value.filter(tpl => {
    const status = tpl.status || 'unsubmitted';
    return status === activeTab.value;
  });
});

const STATUS_CONFIG = {
  approved: {
    classes: 'bg-green-50 text-green-700 ring-1 ring-green-200',
    icon: 'i-lucide-check-circle',
  },
  pending: {
    classes: 'bg-yellow-50 text-yellow-700 ring-1 ring-yellow-200',
    icon: 'i-lucide-clock',
  },
  rejected: {
    classes: 'bg-ruby-50 text-ruby-700 ring-1 ring-ruby-200',
    icon: 'i-lucide-x-circle',
  },
  unsubmitted: {
    classes: 'bg-n-slate-2 text-n-slate-9 ring-1 ring-n-weak',
    icon: 'i-lucide-circle-dashed',
  },
};

function statusConfig(status) {
  return STATUS_CONFIG[status] || STATUS_CONFIG.unsubmitted;
}

function typeLabel(type) {
  return (type || 'text')
    .replace(/_/g, ' ')
    .replace(/\b\w/g, c => c.toUpperCase());
}

function statusLabel(status) {
  if (!status || status === 'unsubmitted') return 'Not Submitted';
  return status.charAt(0).toUpperCase() + status.slice(1);
}

function languageName(code) {
  if (!code) return '';
  try {
    return new Intl.DisplayNames(['en'], { type: 'language' }).of(code) || code;
  } catch {
    return code;
  }
}

async function fetchTemplates() {
  isLoading.value = true;
  try {
    const { data } = await twilioTemplatesApi.list(props.inbox.id);
    templates.value = data.templates || [];
    if (activeTab.value !== 'all') {
      const stillHasItems = templates.value.some(
        t => (t.status || 'unsubmitted') === activeTab.value
      );
      if (!stillHasItems) activeTab.value = 'all';
    }
  } catch {
    useAlert(t('TWILIO_TEMPLATES.LIST.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
}

function openCreate() {
  editingTemplate.value = null;
  prefillTemplate.value = null;
  showTemplateModal.value = true;
}

function openView(tpl) {
  viewingTemplate.value = tpl;
}

function openDuplicate(tpl) {
  editingTemplate.value = null;
  prefillTemplate.value = tpl;
  viewingTemplate.value = null;
  showTemplateModal.value = true;
}

function openApproval(tpl) {
  approvalTarget.value = tpl;
  showApprovalModal.value = true;
}

async function handleSync() {
  isSyncing.value = true;
  try {
    const { data } = await twilioTemplatesApi.sync(props.inbox.id);
    templates.value = data.templates || [];
    useAlert(t('TWILIO_TEMPLATES.LIST.SYNC_SUCCESS'));
  } catch {
    useAlert(t('TWILIO_TEMPLATES.LIST.SYNC_ERROR'));
  } finally {
    isSyncing.value = false;
  }
}

async function handleSave(payload) {
  try {
    if (editingTemplate.value) {
      const { data } = await twilioTemplatesApi.update(
        props.inbox.id,
        editingTemplate.value.content_sid,
        payload
      );
      const updated = data.template;
      templates.value = templates.value
        .filter(tmpl => tmpl.content_sid !== editingTemplate.value.content_sid)
        .concat(updated || []);
      useAlert(t('TWILIO_TEMPLATES.LIST.UPDATE_SUCCESS'));
    } else {
      const { data } = await twilioTemplatesApi.create(props.inbox.id, payload);
      if (data.template) templates.value = [...templates.value, data.template];
      useAlert(t('TWILIO_TEMPLATES.LIST.CREATE_SUCCESS'));
    }
    showTemplateModal.value = false;
  } catch (e) {
    const msg =
      e?.response?.data?.error || t('TWILIO_TEMPLATES.LIST.SAVE_ERROR');
    useAlert(msg);
  }
}

function handleDelete(tpl) {
  deleteTarget.value = tpl;
  deleteDialogRef.value.open();
}

async function confirmDelete() {
  const tpl = deleteTarget.value;
  if (!tpl) return;
  try {
    await twilioTemplatesApi.delete(props.inbox.id, tpl.content_sid);
    templates.value = templates.value.filter(
      tmpl => tmpl.content_sid !== tpl.content_sid
    );
    if (viewingTemplate.value?.content_sid === tpl.content_sid)
      viewingTemplate.value = null;
    useAlert(t('TWILIO_TEMPLATES.LIST.DELETE_SUCCESS'));
  } catch (e) {
    const msg =
      e?.response?.data?.error || t('TWILIO_TEMPLATES.LIST.DELETE_ERROR');
    useAlert(msg);
  } finally {
    deleteTarget.value = null;
    deleteDialogRef.value?.close();
  }
}

async function handleSubmitApproval({ name, category }) {
  try {
    const { data } = await twilioTemplatesApi.submitApproval(
      props.inbox.id,
      approvalTarget.value.content_sid,
      { name, category }
    );
    if (data.new_content_sid) {
      templates.value = templates.value.map(tpl =>
        tpl.content_sid === approvalTarget.value.content_sid
          ? { ...tpl, content_sid: data.new_content_sid, status: 'pending' }
          : tpl
      );
    } else {
      templates.value = templates.value.map(tpl =>
        tpl.content_sid === approvalTarget.value.content_sid
          ? { ...tpl, status: 'pending' }
          : tpl
      );
    }
    useAlert(t('TWILIO_TEMPLATES.APPROVAL.SUCCESS'));
    showApprovalModal.value = false;
  } catch (e) {
    const msg =
      e?.response?.data?.error || t('TWILIO_TEMPLATES.APPROVAL.ERROR');
    useAlert(msg);
  }
}

useEmitter(BUS_EVENTS.ACCOUNT_CACHE_INVALIDATED, fetchTemplates);

let tabsResizeObserver = null;

onMounted(async () => {
  await fetchTemplates();
  handleSync();
  if (tabsScrollRef.value) {
    tabsScrollRef.value.addEventListener('scroll', updateScrollState);
    tabsResizeObserver = new ResizeObserver(updateScrollState);
    tabsResizeObserver.observe(tabsScrollRef.value);
    updateScrollState();
  }
});

onBeforeUnmount(() => {
  tabsScrollRef.value?.removeEventListener('scroll', updateScrollState);
  tabsResizeObserver?.disconnect();
});
</script>

<template>
  <div class="flex flex-col gap-5">
    <TemplateDetail
      v-if="viewingTemplate"
      :template="viewingTemplate"
      @back="viewingTemplate = null"
      @delete="handleDelete"
      @duplicate="openDuplicate"
      @submit-approval="openApproval"
    />

    <template v-else>
      <div
        class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between pt-10"
      >
        <div>
          <h3 class="text-base font-semibold text-n-slate-12">
            {{ t('TWILIO_TEMPLATES.LIST.TITLE') }}
          </h3>
          <p class="text-sm text-n-slate-9 mt-0.5">
            {{ t('TWILIO_TEMPLATES.LIST.SUBTITLE') }}
          </p>
        </div>
        <div class="flex items-center gap-2 shrink-0">
          <button
            class="flex items-center gap-1.5 px-3 py-2 text-sm border border-n-weak text-n-slate-11 hover:bg-n-slate-2 rounded-lg transition-colors disabled:opacity-50"
            :disabled="isSyncing"
            @click="handleSync"
          >
            <Icon
              icon="i-lucide-refresh-cw"
              class="size-4"
              :class="{ 'animate-spin': isSyncing }"
            />
            <span class="hidden sm:inline">
              {{
                isSyncing
                  ? t('TWILIO_TEMPLATES.LIST.SYNCING')
                  : t('TWILIO_TEMPLATES.LIST.SYNC_BUTTON')
              }}
            </span>
          </button>
          <button
            class="flex items-center gap-1.5 px-3 py-2 text-sm bg-[#182933] hover:bg-[#182933]/90 text-white rounded-lg transition-colors"
            @click="openCreate"
          >
            <Icon icon="i-lucide-plus" class="size-4" />
            <span class="hidden sm:inline">{{
              t('TWILIO_TEMPLATES.LIST.NEW_BUTTON')
            }}</span>
            <span class="sm:hidden">{{
              t('TWILIO_TEMPLATES.LIST.NEW_SHORT')
            }}</span>
          </button>
        </div>
      </div>

      <!-- Tabs -->
      <div class="relative flex items-center border-b border-n-weak">
        <button
          v-if="canScrollLeft"
          class="shrink-0 flex items-center justify-center size-9 text-n-slate-9 hover:text-n-slate-12 bg-n-slate-1 border-r border-n-weak transition-colors z-10"
          @click="scrollTabs(-1)"
        >
          <Icon icon="i-lucide-chevron-left" class="size-6" />
        </button>

        <div
          ref="tabsScrollRef"
          class="flex items-center overflow-x-auto scrollbar-hide flex-1"
        >
          <button
            v-for="tab in TABS"
            :key="tab.key"
            class="shrink-0 px-3 py-2 text-xs sm:text-sm sm:px-4 font-medium transition-colors relative whitespace-nowrap"
            :class="
              activeTab === tab.key
                ? 'text-[#182933] dark:text-[#396681] after:absolute after:bottom-0 after:left-0 after:right-0 after:h-0.5 after:bg-[#182933] dark:after:bg-[#396681]'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="activeTab = tab.key"
          >
            {{ tab.label }}
            <span
              class="ml-1.5 text-xs px-1.5 py-0.5 rounded-full"
              :class="activeTab === tab.key ? 'bg-[#182933]/10 text-[#182933] dark:bg-[#396681]/20 dark:text-[#7eb8d4]' : 'bg-n-slate-3 text-n-slate-9'"
            >
              {{ tab.key === 'all' ? templates.length : templates.filter(t => (t.status || 'unsubmitted') === tab.key).length }}
            </span>
          </button>
        </div>

        <button
          v-if="canScrollRight"
          class="shrink-0 flex items-center justify-center size-9 text-n-slate-11 hover:text-n-slate-12 bg-n-slate-1 border-l border-n-weak transition-colors z-10"
          @click="scrollTabs(1)"
        >
          <Icon icon="i-lucide-chevron-right" class="size-6" />
        </button>
      </div>

      <div
        v-if="isLoading"
        class="flex flex-col items-center justify-center py-16 gap-3"
      >
        <Icon
          icon="i-lucide-loader-2"
          class="size-6 text-[#182933] animate-spin"
        />
        <p class="text-sm text-n-slate-9">
          {{ t('TWILIO_TEMPLATES.LIST.LOADING') }}
        </p>
      </div>

      <div
        v-else-if="filteredTemplates.length === 0"
        class="flex flex-col items-center justify-center py-16 gap-4 border-2 border-dashed border-n-weak rounded-2xl bg-n-slate-1"
      >
        <p class="text-lg text-n-slate-9">
          {{ activeTab === 'all' ? t('TWILIO_TEMPLATES.LIST.EMPTY') : t('TWILIO_TEMPLATES.LIST.EMPTY_FILTERED') }}
        </p>
        <button
          v-if="activeTab === 'all'"
          class="flex items-center gap-1.5 px-4 py-2 text-sm bg-[#182933] hover:bg-[#182933]/90 text-white rounded-lg transition-colors"
          @click="openCreate"
        >
          <Icon icon="i-lucide-plus" class="size-4" />
          {{ t('TWILIO_TEMPLATES.LIST.NEW_BUTTON') }}
        </button>
      </div>

      <div v-else class="grid grid-cols-1 gap-3 pb-12">
        <div
          v-for="tpl in filteredTemplates"
          :key="tpl.content_sid"
          class="group relative flex flex-col gap-3 p-4 bg-n-slate-1 border border-n-strong rounded-xl hover:border-[#182933]/40 hover:shadow-sm transition-all"
        >
          <div class="flex flex-col gap-1.5 sm:flex-row sm:items-center sm:justify-between sm:gap-2">
            <div class="flex items-center gap-2 min-w-0">
              <button
                class="text-sm font-semibold text-n-slate-12 truncate hover:text-[#182933] transition-colors text-left"
                @click="openView(tpl)"
              >
                {{ tpl.friendly_name }}
              </button>
              <span
                class="hidden sm:inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full capitalize shrink-0 font-medium"
                :class="statusConfig(tpl.status).classes"
              >
                <Icon :icon="statusConfig(tpl.status).icon" class="size-3" />
                {{ statusLabel(tpl.status) }}
              </span>
            </div>
            <div class="flex items-center justify-between sm:justify-end gap-2 shrink-0">
              <span
                class="sm:hidden inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full capitalize shrink-0 font-medium"
                :class="statusConfig(tpl.status).classes"
              >
                <Icon :icon="statusConfig(tpl.status).icon" class="size-3" />
                {{ statusLabel(tpl.status) }}
              </span>
              <div class="flex items-center gap-1">
                <button
                  class="p-1.5 rounded-lg text-n-slate-9 hover:text-[#182933] hover:bg-[#182933]/10 transition-colors"
                  :title="t('TWILIO_TEMPLATES.DETAIL.VIEW')"
                  @click="openView(tpl)"
                >
                  <Icon icon="i-lucide-eye" class="size-3.5" />
                </button>
                <button
                  class="p-1.5 rounded-lg text-n-slate-9 hover:text-red-600 transition-colors"
                  :title="t('TWILIO_TEMPLATES.LIST.DELETE')"
                  @click="handleDelete(tpl)"
                >
                  <Icon icon="i-lucide-trash-2" class="size-3.5" />
                </button>
              </div>
            </div>
          </div>

          <div>
            <p class="text-xs font-medium text-n-slate-9 mb-1">
              {{ t('TWILIO_TEMPLATES.FORM.BODY') }}
            </p>
            <p
              v-if="tpl.body"
              class="text-sm text-n-slate-10 leading-relaxed line-clamp-2"
            >
              {{ tpl.body }}
            </p>
            <p v-else class="text-xs text-n-slate-8 italic">
              {{ t('TWILIO_TEMPLATES.LIST.NO_BODY') }}
            </p>
          </div>

          <div
            class="flex flex-wrap items-center justify-between gap-2 pt-1 border-t border-n-strong"
          >
            <div class="flex items-center gap-2">
              <span
                class="inline-flex items-center gap-1 text-xs px-2 py-0.5 bg-n-slate-2 text-n-slate-10 rounded-md font-medium"
              >
                <Icon icon="i-lucide-layout-template" class="size-3" />
                {{ typeLabel(tpl.template_type) }}
              </span>
              <span
                v-if="tpl.language"
                class="inline-flex items-center gap-1 text-xs px-2 py-0.5 bg-n-slate-2 text-n-slate-10 rounded-md font-medium"
              >
                <Icon icon="i-lucide-globe" class="size-3" />
                {{ languageName(tpl.language) }}
              </span>
            </div>
            <button
              v-if="tpl.status !== 'approved' && tpl.status !== 'pending'"
              class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-[#182933]/10 text-[#182933] hover:bg-[#182933]/20 border border-[#182933]/20 dark:bg-n-slate-4 dark:text-n-slate-11 dark:hover:bg-n-slate-5 dark:border-n-slate-6 rounded-lg transition-colors"
              @click="openApproval(tpl)"
            >
              <Icon icon="i-lucide-send" class="size-3" />
              {{ t('TWILIO_TEMPLATES.LIST.SUBMIT_APPROVAL') }}
            </button>
          </div>
        </div>
      </div>
    </template>

    <TemplateModal
      v-model:show="showTemplateModal"
      :template="editingTemplate"
      :prefill="prefillTemplate"
      @on-save="handleSave"
    />

    <SubmitApprovalModal
      v-model:show="showApprovalModal"
      :template="approvalTarget"
      @on-submit="handleSubmitApproval"
    />

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('TWILIO_TEMPLATES.LIST.DELETE_TITLE')"
      :description="
        t('TWILIO_TEMPLATES.LIST.DELETE_CONFIRM', {
          name: deleteTarget?.friendly_name,
        })
      "
      :confirm-button-label="t('TWILIO_TEMPLATES.LIST.DELETE_CONFIRM_BUTTON')"
      :cancel-button-label="t('TWILIO_TEMPLATES.LIST.DELETE_CANCEL_BUTTON')"
      @confirm="confirmDelete"
    />
  </div>
</template>
