<script setup>
import { reactive, ref, computed, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';

const props = defineProps({
  offer: {
    type: Object,
    default: () => ({}),
  },
  submitLabel: {
    type: String,
    default: '',
  },
  heading: {
    type: String,
    default: '',
  },
  isSubmitting: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['submit', 'cancel']);
const { t } = useI18n();

const headingText = computed(
  () => props.heading || t('OFFERS_MGMT.FORM.HEADING')
);
const submitText = computed(
  () => props.submitLabel || t('OFFERS_MGMT.FORM.SUBMIT')
);

const defaultForm = { title: '', start_date: '', end_date: '', source_url: '' };

const form = reactive({ ...defaultForm, ...props.offer });
const errors = reactive({
  title: '',
  start_date: '',
  end_date: '',
  offer_document: '',
  source_url: '',
});
const selectedFile = ref(null);
const fileInputRef = ref(null);

const MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024;

const existingDocumentUrl = computed(() => props.offer?.offer_document || '');
const documentRemoved = ref(false);
const existingDocumentActive = computed(
  () => !!existingDocumentUrl.value && !documentRemoved.value
);
const hasDocumentValue = computed(
  () => !!selectedFile.value || existingDocumentActive.value
);
const hasSourceUrlValue = computed(() => !!form.source_url?.trim());

const sourceMode = ref(props.offer?.source_url ? 'url' : 'document');
const sourceTabs = computed(() => [
  {
    label: t('OFFERS_MGMT.FORM.PDF.LABEL'),
    disabled: sourceMode.value !== 'document' && hasSourceUrlValue.value,
  },
  {
    label: t('OFFERS_MGMT.FORM.SOURCE_URL.LABEL'),
    disabled: sourceMode.value !== 'url' && hasDocumentValue.value,
  },
]);
const activeSourceTabIndex = computed(() =>
  sourceMode.value === 'url' ? 1 : 0
);

watch(
  () => props.offer,
  value => {
    Object.assign(form, defaultForm, value);
    selectedFile.value = null;
    documentRemoved.value = false;
    sourceMode.value = value?.source_url ? 'url' : 'document';
    Object.keys(errors).forEach(key => {
      errors[key] = '';
    });
  }
);

const selectedFileSizeLabel = computed(() => {
  if (!selectedFile.value) return '';
  const { size } = selectedFile.value;
  if (size < 1024 * 1024) {
    return t('OFFERS_MGMT.FORM.PDF.FILE_SIZE_KB', {
      size: Math.max(size / 1024, 0.1).toFixed(1),
    });
  }
  return t('OFFERS_MGMT.FORM.PDF.FILE_SIZE', {
    size: (size / 1024 / 1024).toFixed(2),
  });
});

const openFileDialog = () => {
  nextTick(() => fileInputRef.value?.click());
};

const handleFileChange = event => {
  const file = event.target.files[0];
  if (!file) return;

  if (file.size > MAX_FILE_SIZE_BYTES) {
    errors.offer_document = t('OFFERS_MGMT.FORM.VALIDATION_FILE_SIZE');
    selectedFile.value = null;
    if (fileInputRef.value) fileInputRef.value.value = '';
    return;
  }

  selectedFile.value = file;
  errors.offer_document = '';
};

const clearSelectedFile = () => {
  selectedFile.value = null;
  if (fileInputRef.value) fileInputRef.value.value = '';
};

const removeExistingDocument = () => {
  documentRemoved.value = true;
  errors.offer_document = '';
};

const clearSourceUrl = () => {
  form.source_url = '';
  errors.source_url = '';
};

const handleSourceTabChanged = tab => {
  const mode = tab === sourceTabs.value[1] ? 'url' : 'document';
  sourceMode.value = mode;
};

const isValidUrl = value => {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch (error) {
    return false;
  }
};

const validateForm = () => {
  let isValid = true;
  if (!form.title?.trim()) {
    errors.title = t('OFFERS_MGMT.FORM.VALIDATION_REQUIRED');
    isValid = false;
  }
  if (!form.start_date) {
    errors.start_date = t('OFFERS_MGMT.FORM.VALIDATION_REQUIRED');
    isValid = false;
  }
  if (!form.end_date) {
    errors.end_date = t('OFFERS_MGMT.FORM.VALIDATION_REQUIRED');
    isValid = false;
  }
  if (
    form.start_date &&
    form.end_date &&
    new Date(form.end_date) < new Date(form.start_date)
  ) {
    errors.end_date = t('OFFERS_MGMT.FORM.VALIDATION_DATE_ORDER');
    isValid = false;
  }
  if (sourceMode.value === 'document') {
    if (!selectedFile.value && !existingDocumentActive.value) {
      errors.offer_document = t('OFFERS_MGMT.FORM.VALIDATION_REQUIRED_FILE');
      isValid = false;
    }
  } else if (!form.source_url?.trim()) {
    errors.source_url = t('OFFERS_MGMT.FORM.VALIDATION_REQUIRED_URL');
    isValid = false;
  } else if (!isValidUrl(form.source_url.trim())) {
    errors.source_url = t('OFFERS_MGMT.FORM.VALIDATION_INVALID_URL');
    isValid = false;
  }
  return isValid;
};

watch(
  () => form.title,
  value => {
    if (value?.trim()) errors.title = '';
  }
);
watch(
  () => form.start_date,
  () => {
    if (form.start_date) errors.start_date = '';
  }
);
watch(
  () => form.end_date,
  () => {
    if (form.end_date) errors.end_date = '';
  }
);
watch(
  () => form.source_url,
  value => {
    if (value?.trim()) errors.source_url = '';
  }
);

const isFormValid = computed(() => {
  if (!form.title?.trim()) return false;
  if (!form.start_date || !form.end_date) return false;
  if (new Date(form.end_date) < new Date(form.start_date)) return false;
  if (sourceMode.value === 'document') {
    return !!(selectedFile.value || existingDocumentActive.value);
  }
  return !!form.source_url?.trim() && isValidUrl(form.source_url.trim());
});

const handleSubmit = () => {
  if (!validateForm()) return;
  emit('submit', {
    title: form.title.trim(),
    start_date: form.start_date,
    end_date: form.end_date,
    offer_document: sourceMode.value === 'document' ? selectedFile.value : null,
    source_url: sourceMode.value === 'url' ? form.source_url.trim() : '',
    remove_offer_document:
      sourceMode.value === 'url' && !!existingDocumentUrl.value,
  });
};

const handleCancel = () => emit('cancel');
</script>

<template>
  <div class="flex flex-col w-full gap-4">
    <header>
      <h2 class="text-lg font-semibold text-n-slate-12">
        {{ headingText }}
      </h2>
    </header>

    <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
      <Input
        v-model="form.title"
        required
        :label="t('OFFERS_MGMT.FORM.TITLE.LABEL')"
        :placeholder="t('OFFERS_MGMT.FORM.TITLE.PLACEHOLDER')"
        :message="errors.title"
        :message-type="errors.title ? 'error' : 'info'"
      />

      <div class="grid gap-4 sm:grid-cols-2">
        <Input
          v-model="form.start_date"
          type="date"
          required
          :label="t('OFFERS_MGMT.FORM.START_DATE.LABEL')"
          :message="errors.start_date"
          :message-type="errors.start_date ? 'error' : 'info'"
        />
        <Input
          v-model="form.end_date"
          type="date"
          :min="form.start_date"
          required
          :label="t('OFFERS_MGMT.FORM.END_DATE.LABEL')"
          :message="errors.end_date"
          :message-type="errors.end_date ? 'error' : 'info'"
        />
      </div>

      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('OFFERS_MGMT.FORM.SOURCE_LABEL') }}
        </label>
        <p class="m-0 text-xs text-n-slate-11">
          {{ t('OFFERS_MGMT.FORM.SOURCE_HELP') }}
        </p>
        <TabBar
          :tabs="sourceTabs"
          :initial-active-tab="activeSourceTabIndex"
          @tab-changed="handleSourceTabChanged"
        />

        <template v-if="sourceMode === 'document'">
          <input
            ref="fileInputRef"
            type="file"
            class="hidden"
            @change="handleFileChange"
          />
          <Button
            type="button"
            variant="outline"
            color="slate"
            class="!w-full !h-auto !justify-between !py-3"
            @click="openFileDialog"
          >
            <div class="flex items-center flex-1 gap-2">
              <div
                class="flex items-center justify-center rounded-lg size-9 bg-n-slate-3"
              >
                <i class="text-lg i-lucide-file-text text-n-slate-11" />
              </div>
              <div class="flex flex-col items-start flex-1 gap-0.5">
                <p class="m-0 text-sm font-medium text-n-slate-12">
                  {{
                    selectedFile
                      ? selectedFile.name
                      : t('OFFERS_MGMT.FORM.PDF.CHOOSE_FILE')
                  }}
                </p>
                <p class="m-0 text-xs text-n-slate-11">
                  <template v-if="selectedFile">
                    {{ selectedFileSizeLabel }}
                  </template>
                  <template v-else-if="existingDocumentActive">
                    {{ t('OFFERS_MGMT.FORM.PDF.REPLACE_HELP') }}
                  </template>
                  <template v-else>
                    {{ t('OFFERS_MGMT.FORM.PDF.HELP_TEXT') }}
                  </template>
                </p>
              </div>
            </div>
            <i class="i-lucide-upload text-n-slate-11" />
          </Button>
          <div v-if="selectedFile" class="flex">
            <Button
              type="button"
              variant="ghost"
              color="ruby"
              size="xs"
              :label="t('OFFERS_MGMT.FORM.PDF.REMOVE')"
              @click="clearSelectedFile"
            />
          </div>
          <div
            v-else-if="existingDocumentActive"
            class="flex items-center gap-3"
          >
            <a
              :href="existingDocumentUrl"
              target="_blank"
              rel="noopener noreferrer"
              class="text-sm text-n-brand hover:underline w-fit"
            >
              {{ t('OFFERS_MGMT.FORM.PDF.VIEW_CURRENT') }}
            </a>
            <Button
              type="button"
              variant="ghost"
              color="ruby"
              size="xs"
              :label="t('OFFERS_MGMT.FORM.PDF.REMOVE_CURRENT')"
              @click="removeExistingDocument"
            />
          </div>
          <p
            v-if="errors.offer_document"
            class="text-xs text-n-ruby-9 dark:text-n-ruby-9"
          >
            {{ errors.offer_document }}
          </p>
        </template>

        <template v-else>
          <Input
            v-model="form.source_url"
            type="url"
            :placeholder="t('OFFERS_MGMT.FORM.SOURCE_URL.PLACEHOLDER')"
            :message="errors.source_url"
            :message-type="errors.source_url ? 'error' : 'info'"
          />
          <div v-if="form.source_url" class="flex">
            <Button
              type="button"
              variant="ghost"
              color="ruby"
              size="xs"
              :label="t('OFFERS_MGMT.FORM.SOURCE_URL.REMOVE')"
              @click="clearSourceUrl"
            />
          </div>
        </template>
      </div>

      <footer class="flex justify-end gap-3 mt-2">
        <Button
          type="button"
          variant="faded"
          color="slate"
          :label="t('OFFERS_MGMT.FORM.CANCEL')"
          @click="handleCancel"
        />
        <Button
          type="submit"
          :label="submitText"
          :is-loading="isSubmitting"
          :disabled="isSubmitting || !isFormValid"
        />
      </footer>
    </form>
  </div>
</template>
