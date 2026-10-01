<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import metaTemplatesApi from 'dashboard/api/metaTemplates';
import { templatePreviewText } from 'dashboard/helper/metaTemplateHelper';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TemplateModal from './TemplateModal.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  inbox: { type: Object, required: true },
});

const { t } = useI18n();

const templates = ref([]);
const isLoading = ref(false);
const isSaving = ref(false);
const showTemplateModal = ref(false);
const editingTemplate = ref(null);
const deleteTarget = ref(null);
const deleteDialogRef = ref(null);

const CATEGORY_LABEL_KEYS = {
  text: 'META_TEMPLATES.CATEGORIES.TEXT',
  quick_reply: 'META_TEMPLATES.CATEGORIES.QUICK_REPLY',
  media: 'META_TEMPLATES.CATEGORIES.MEDIA',
  call_to_action: 'META_TEMPLATES.CATEGORIES.CALL_TO_ACTION',
  card: 'META_TEMPLATES.CATEGORIES.CARD',
};

function categoryLabel(category) {
  const key = CATEGORY_LABEL_KEYS[category];
  return key ? t(key) : category;
}

async function fetchTemplates() {
  isLoading.value = true;
  try {
    const { data } = await metaTemplatesApi.list(props.inbox.id);
    templates.value = data.templates || [];
  } catch {
    useAlert(t('META_TEMPLATES.LIST.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
}

function openCreate() {
  editingTemplate.value = null;
  showTemplateModal.value = true;
}

function openEdit(tpl) {
  editingTemplate.value = tpl;
  showTemplateModal.value = true;
}

async function handleSave(payload) {
  if (isSaving.value) return;
  isSaving.value = true;
  try {
    if (editingTemplate.value) {
      const { data } = await metaTemplatesApi.update(
        props.inbox.id,
        editingTemplate.value.id,
        payload
      );
      templates.value = templates.value.map(tpl =>
        tpl.id === editingTemplate.value.id ? data.template : tpl
      );
      useAlert(t('META_TEMPLATES.LIST.UPDATE_SUCCESS'));
    } else {
      const { data } = await metaTemplatesApi.create(props.inbox.id, payload);
      templates.value = [...templates.value, data.template];
      useAlert(t('META_TEMPLATES.LIST.CREATE_SUCCESS'));
    }
    showTemplateModal.value = false;
  } catch (e) {
    useAlert(e?.response?.data?.error || t('META_TEMPLATES.LIST.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
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
    await metaTemplatesApi.delete(props.inbox.id, tpl.id);
    templates.value = templates.value.filter(t2 => t2.id !== tpl.id);
    useAlert(t('META_TEMPLATES.LIST.DELETE_SUCCESS'));
  } catch (e) {
    useAlert(e?.response?.data?.error || t('META_TEMPLATES.LIST.DELETE_ERROR'));
  } finally {
    deleteTarget.value = null;
    deleteDialogRef.value?.close();
  }
}

onMounted(fetchTemplates);
</script>

<template>
  <div class="flex flex-col gap-5">
    <div class="flex items-center justify-between pt-10">
      <div>
        <h3 class="text-base font-semibold text-n-slate-12">
          {{ t('META_TEMPLATES.LIST.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-9 mt-0.5">
          {{ t('META_TEMPLATES.LIST.SUBTITLE') }}
        </p>
      </div>
      <button
        class="flex items-center gap-1.5 px-3 py-2 text-sm bg-n-brand hover:bg-n-brand/90 text-white rounded-lg transition-colors"
        @click="openCreate"
      >
        <Icon icon="i-lucide-plus" class="size-4" />
        {{ t('META_TEMPLATES.LIST.NEW_BUTTON') }}
      </button>
    </div>

    <div v-if="isLoading" class="flex justify-center py-16">
      <Icon icon="i-lucide-loader-2" class="size-6 text-n-brand animate-spin" />
    </div>

    <div
      v-else-if="templates.length === 0"
      class="flex flex-col items-center justify-center py-16 gap-4 border-2 border-dashed border-n-weak rounded-2xl bg-n-slate-1"
    >
      <p class="text-sm text-n-slate-9">{{ t('META_TEMPLATES.LIST.EMPTY') }}</p>
      <button
        class="flex items-center gap-1.5 px-4 py-2 text-sm bg-n-brand hover:bg-n-brand/90 text-white rounded-lg"
        @click="openCreate"
      >
        <Icon icon="i-lucide-plus" class="size-4" />
        {{ t('META_TEMPLATES.LIST.NEW_BUTTON') }}
      </button>
    </div>

    <div v-else class="grid grid-cols-1 gap-3 pb-12">
      <div
        v-for="tpl in templates"
        :key="tpl.id"
        class="flex items-center justify-between gap-3 p-4 bg-n-slate-1 border border-n-strong rounded-xl"
      >
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <p class="text-sm font-semibold text-n-slate-12 truncate">
              {{ tpl.name }}
            </p>
            <span
              class="text-xs px-2 py-0.5 bg-n-slate-2 text-n-slate-10 rounded-md font-medium"
            >
              {{ categoryLabel(tpl.category) }}
            </span>
          </div>
          <p
            v-if="templatePreviewText(tpl.content, tpl.category)"
            class="text-xs text-n-slate-10 mt-1 truncate"
          >
            {{ templatePreviewText(tpl.content, tpl.category) }}
          </p>
        </div>
        <div class="flex items-center gap-1 shrink-0">
          <button
            class="p-1.5 rounded-lg text-n-slate-9 hover:text-n-brand hover:bg-n-brand/10"
            :title="t('META_TEMPLATES.LIST.EDIT')"
            @click="openEdit(tpl)"
          >
            <Icon icon="i-lucide-pencil" class="size-3.5" />
          </button>
          <button
            class="p-1.5 rounded-lg text-n-slate-9 hover:text-red-600"
            :title="t('META_TEMPLATES.LIST.DELETE')"
            @click="handleDelete(tpl)"
          >
            <Icon icon="i-lucide-trash-2" class="size-3.5" />
          </button>
        </div>
      </div>
    </div>

    <TemplateModal
      v-model:show="showTemplateModal"
      :template="editingTemplate"
      :is-saving="isSaving"
      @on-save="handleSave"
    />

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('META_TEMPLATES.LIST.DELETE_TITLE')"
      :description="
        t('META_TEMPLATES.LIST.DELETE_CONFIRM', { name: deleteTarget?.name })
      "
      :confirm-button-label="t('META_TEMPLATES.LIST.DELETE_CONFIRM_BUTTON')"
      :cancel-button-label="t('META_TEMPLATES.LIST.DELETE_CANCEL_BUTTON')"
      @confirm="confirmDelete"
    />
  </div>
</template>
