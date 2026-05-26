<script setup>
import { ref, watch, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  template: { type: Object, default: null },
  prefill: { type: Object, default: null },
});

const emit = defineEmits(['update:show', 'onSave']);

const { t } = useI18n();

const isSaving = ref(false);
const localShow = ref(props.show);
watch(
  () => props.show,
  v => {
    localShow.value = v;
    if (v) {
      if (props.template) applySource(props.template, true);
      else if (props.prefill) applySource(props.prefill, false);
      else form.value = emptyForm();
    }
  }
);

const CONTENT_TYPES = [
  {
    key: 'twilio/text',
    label: t('TWILIO_TEMPLATES.CONTENT_TYPES.TEXT'),
    icon: 'i-lucide-type',
  },
  {
    key: 'twilio/media',
    label: t('TWILIO_TEMPLATES.CONTENT_TYPES.MEDIA'),
    icon: 'i-lucide-image',
  },
  {
    key: 'twilio/quick-reply',
    label: t('TWILIO_TEMPLATES.CONTENT_TYPES.QUICK_REPLY'),
    icon: 'i-lucide-mouse-pointer-click',
  },
  {
    key: 'twilio/call-to-action',
    label: t('TWILIO_TEMPLATES.CONTENT_TYPES.CALL_TO_ACTION'),
    icon: 'i-lucide-external-link',
  },
  {
    key: 'twilio/list-picker',
    label: t('TWILIO_TEMPLATES.CONTENT_TYPES.LIST_PICKER'),
    icon: 'i-lucide-list',
  },
  {
    key: 'twilio/card',
    label: t('TWILIO_TEMPLATES.CONTENT_TYPES.CARD'),
    icon: 'i-lucide-layout',
  },
];

const LANGUAGES = [
  { code: 'en', label: 'English' },
  { code: 'en-GB', label: 'English (UK)' },
  { code: 'es', label: 'Spanish' },
  { code: 'es-MX', label: 'Spanish (Mexico)' },
  { code: 'fr', label: 'French' },
  { code: 'de', label: 'German' },
  { code: 'pt-BR', label: 'Portuguese (Brazil)' },
  { code: 'pt', label: 'Portuguese' },
  { code: 'it', label: 'Italian' },
  { code: 'ja', label: 'Japanese' },
  { code: 'ko', label: 'Korean' },
  { code: 'ar', label: 'Arabic' },
  { code: 'zh-CN', label: 'Chinese (Simplified)' },
  { code: 'zh-TW', label: 'Chinese (Traditional)' },
  { code: 'nl', label: 'Dutch' },
  { code: 'ru', label: 'Russian' },
  { code: 'id', label: 'Indonesian' },
  { code: 'tr', label: 'Turkish' },
  { code: 'hi', label: 'Hindi' },
  { code: 'pl', label: 'Polish' },
];

const emptyForm = () => ({
  name: '',
  language: 'en',
  template_type: 'twilio/text',
  body: '',
  media_url: '',
  title: '',
  buttons: [],
  actions: [],
  card_actions: [],
  list_button: '',
  list_items: [],
});

const form = ref(emptyForm());

function deriveType(type) {
  const map = {
    quick_reply: 'twilio/quick-reply',
    media: 'twilio/media',
    text: 'twilio/text',
    call_to_action: 'twilio/call-to-action',
    list_picker: 'twilio/list-picker',
    card: 'twilio/card',
    catalog: 'twilio/catalog',
    carousel: 'twilio/carousel',
  };
  return map[type] || type || 'twilio/text';
}

function applySource(src, isEdit) {
  const type = deriveType(src.template_type);
  form.value = {
    name: isEdit ? src.friendly_name || '' : '',
    language: src.language || 'en',
    template_type: type,
    body: src.body || '',
    title: src.types?.['twilio/card']?.title || '',
    media_url:
      src.types?.['twilio/media']?.media?.[0] ||
      src.types?.['twilio/card']?.media?.[0] ||
      '',
    buttons:
      src.types?.['twilio/quick-reply']?.actions?.map(a => ({
        title: a.title,
        id: a.id || '',
      })) || [],
    actions:
      src.types?.['twilio/call-to-action']?.actions?.map(a => ({ ...a })) || [],
    card_actions:
      src.types?.['twilio/card']?.actions?.map(a => ({ ...a })) || [],
    list_button: src.types?.['twilio/list-picker']?.button || '',
    list_items:
      src.types?.['twilio/list-picker']?.items?.map(item => ({
        id: item.id || '',
        title: item.item || item.title || '',
        description: item.description || '',
      })) || [],
  };
}

watch(
  [() => props.template, () => props.prefill],
  ([tpl, prefill]) => {
    if (tpl) applySource(tpl, true);
    else if (prefill) applySource(prefill, false);
    else form.value = emptyForm();
  },
  { immediate: true }
);

const nameError = computed(() => {
  if (!form.value.name) return null;
  return /^[a-z0-9_]+$/.test(form.value.name)
    ? null
    : t('TWILIO_TEMPLATES.FORM.NAME_INVALID');
});

const isQuickReply = computed(
  () => form.value.template_type === 'twilio/quick-reply'
);
const isMedia = computed(() => form.value.template_type === 'twilio/media');
const isCta = computed(
  () => form.value.template_type === 'twilio/call-to-action'
);
const isCard = computed(() => form.value.template_type === 'twilio/card');
const isListPicker = computed(
  () => form.value.template_type === 'twilio/list-picker'
);

const canSave = computed(
  () =>
    form.value.name && !nameError.value && form.value.body && !isSaving.value
);

function selectType(key) {
  form.value.template_type = key;
  form.value.buttons = [];
  form.value.actions = [];
  form.value.card_actions = [];
  form.value.media_url = '';
  form.value.title = '';
  form.value.list_button = '';
  form.value.list_items = [];
}

function addButton() {
  if (form.value.buttons.length < 5)
    form.value.buttons.push({ title: '', id: '' });
}
function removeButton(idx) {
  form.value.buttons.splice(idx, 1);
}

function addAction() {
  if (form.value.actions.length < 4)
    form.value.actions.push({ type: 'URL', title: '', url: '' });
}
function removeAction(idx) {
  form.value.actions.splice(idx, 1);
}

function addCardAction() {
  if (form.value.card_actions.length < 9)
    form.value.card_actions.push({ type: '', title: '', id: '' });
}
function removeCardAction(idx) {
  form.value.card_actions.splice(idx, 1);
}

function addListItem() {
  if (form.value.list_items.length < 10)
    form.value.list_items.push({ id: '', title: '', description: '' });
}
function removeListItem(idx) {
  form.value.list_items.splice(idx, 1);
}

const showSamplesStep = ref(false);
const variableSamples = ref({});

const detectedVariableKeys = computed(() => {
  const matches = form.value.body.match(/\{\{(\d+)\}\}/g) || [];
  return [...new Set(matches.map(m => m.replace(/[{}]/g, '')))].sort(
    (a, b) => Number(a) - Number(b)
  );
});

const allSamplesFilled = computed(() =>
  detectedVariableKeys.value.every(k => variableSamples.value[k]?.trim())
);

function sampleLabel(key) {
  return 'Sample for {{' + key + '}}';
}

function close() {
  showSamplesStep.value = false;
  variableSamples.value = {};
  localShow.value = false;
  emit('update:show', false);
}

function handleSaveClick() {
  if (detectedVariableKeys.value.length > 0) {
    variableSamples.value = {};
    detectedVariableKeys.value.forEach(k => {
      variableSamples.value[k] = '';
    });
    showSamplesStep.value = true;
  } else {
    executeSave({});
  }
}

async function executeSave(samples) {
  isSaving.value = true;
  try {
    await emit('onSave', {
      name: form.value.name,
      language: form.value.language,
      body: form.value.body,
      template_type: form.value.template_type,
      variables: samples,
      buttons: form.value.buttons,
      actions: form.value.actions,
      card_actions: form.value.card_actions,
      media_url: form.value.media_url,
      title: form.value.title,
      list_button: form.value.list_button,
      list_items: form.value.list_items,
    });
    showSamplesStep.value = false;
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="close" size="medium">
    <woot-modal-header
      :header-title="
        template
          ? t('TWILIO_TEMPLATES.MODAL.EDIT_TITLE')
          : t('TWILIO_TEMPLATES.MODAL.CREATE_TITLE')
      "
    />

    <div class="px-8 pb-8 flex flex-col gap-6 overflow-y-auto max-h-[75vh]">
      <!-- General Information -->
      <section class="flex flex-col gap-3">
        <h3
          class="text-sm font-semibold text-n-slate-12 border-b border-n-weak pb-2"
        >
          {{ t('TWILIO_TEMPLATES.FORM.GENERAL_INFO') }}
        </h3>
        <div class="flex flex-col gap-4">
          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('TWILIO_TEMPLATES.FORM.NAME') }}
              <span class="text-ruby-600 ml-0.5">*</span>
            </label>
            <input
              v-model="form.name"
              type="text"
              maxlength="450"
              class="w-full text-sm border border-n-weak rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-[#182933]"
              :class="{ 'border-ruby-400': nameError }"
              :placeholder="t('TWILIO_TEMPLATES.FORM.NAME_PLACEHOLDER')"
            />
            <p v-if="nameError" class="text-xs text-ruby-600">
              {{ nameError }}
            </p>
            <p v-else class="text-xs text-n-slate-9">
              {{ t('TWILIO_TEMPLATES.FORM.NAME_HINT') }}
            </p>
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('TWILIO_TEMPLATES.FORM.LANGUAGE') }}
            </label>
            <select
              v-model="form.language"
              class="w-full text-sm border border-n-weak rounded-lg pl-3 pr-6 py-2 focus:outline-none focus:ring-2 focus:ring-[#182933] bg-n-slate-2 text-n-slate-12"
            >
              <option
                v-for="lang in LANGUAGES"
                :key="lang.code"
                :value="lang.code"
              >
                {{ lang.label }}
              </option>
            </select>
          </div>
        </div>
      </section>

      <!-- Content Type -->
      <section class="flex flex-col gap-3">
        <h3
          class="text-sm font-semibold text-n-slate-12 border-b border-n-weak pb-2"
        >
          {{ t('TWILIO_TEMPLATES.FORM.CONTENT_TYPE') }}
        </h3>
        <div class="grid grid-cols-2 gap-2">
          <button
            v-for="ct in CONTENT_TYPES"
            :key="ct.key"
            type="button"
            class="flex items-center gap-3 px-4 py-3 border rounded-lg transition-colors text-left"
            :class="
              form.template_type === ct.key
                ? 'border-[#182933] bg-[#182933]/10 text-[#182933] ring-1 ring-[#182933]/40 dark:border-n-slate-6 dark:bg-n-slate-4 dark:text-n-slate-12 dark:ring-n-slate-6'
                : 'border-n-weak text-n-slate-11 hover:border-[#182933]/30 hover:bg-[#182933]/5 dark:hover:border-n-slate-6 dark:hover:bg-n-slate-3'
            "
            @click="selectType(ct.key)"
          >
            <div
              class="size-7 rounded flex items-center justify-center shrink-0"
              :class="
                form.template_type === ct.key ? 'bg-[#182933]/20 dark:bg-n-slate-6' : 'bg-n-slate-3'
              "
            >
              <Icon :icon="ct.icon" class="size-4" />
            </div>
            <span class="text-sm font-medium">{{ ct.label }}</span>
          </button>
        </div>
      </section>

      <section class="flex flex-col gap-4">
        <h3
          class="text-sm font-semibold text-n-slate-12 border-b border-n-weak pb-2"
        >
          {{ t('TWILIO_TEMPLATES.FORM.CONFIGURE_CONTENT') }}
        </h3>

        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('TWILIO_TEMPLATES.FORM.BODY') }}
            <span class="text-ruby-600 ml-0.5">*</span>
          </label>
          <textarea
            v-model="form.body"
            rows="4"
            class="w-full text-sm border border-n-weak rounded-lg px-3 py-2 resize-none focus:outline-none focus:ring-2 focus:ring-[#182933]"
            :placeholder="t('TWILIO_TEMPLATES.FORM.BODY_PLACEHOLDER')"
          />
          <p class="text-xs text-n-slate-9">
            {{ t('TWILIO_TEMPLATES.FORM.BODY_HINT') }}
          </p>
        </div>

        <!-- Card Title -->
        <div v-if="isCard" class="flex flex-col gap-1">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('TWILIO_TEMPLATES.FORM.CARD_TITLE') }}
          </label>
          <input
            v-model="form.title"
            type="text"
            class="w-full text-sm border border-n-weak rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-[#182933]"
            :placeholder="t('TWILIO_TEMPLATES.FORM.CARD_TITLE_PLACEHOLDER')"
          />
        </div>

        <!-- Media URL -->
        <div v-if="isMedia || isCard" class="flex flex-col gap-1">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('TWILIO_TEMPLATES.FORM.MEDIA_URL') }}
          </label>
          <input
            v-model="form.media_url"
            type="url"
            class="w-full text-sm border border-n-weak rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-[#182933]"
            :placeholder="t('TWILIO_TEMPLATES.FORM.MEDIA_URL_PLACEHOLDER')"
          />
          <p class="text-xs text-n-slate-9">
            {{ t('TWILIO_TEMPLATES.FORM.MEDIA_URL_HINT') }}
          </p>
        </div>

        <!-- Card Buttons -->
        <div v-if="isCard" class="flex flex-col gap-2">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('TWILIO_TEMPLATES.FORM.BUTTONS') }}
            <span class="text-n-slate-9 font-normal ml-1">(max 9)</span>
          </label>
          <div
            v-for="(action, idx) in form.card_actions"
            :key="idx"
            class="flex flex-col gap-2 p-3 border border-n-weak rounded-lg"
          >
            <div class="flex items-center justify-between">
              <span class="text-xs font-medium text-n-slate-10">Button {{ idx + 1 }}</span>
              <button
                type="button"
                class="text-n-slate-8 hover:text-ruby-600 transition-colors"
                @click="removeCardAction(idx)"
              >
                <Icon icon="i-lucide-trash-2" class="size-3.5" />
              </button>
            </div>
            <!-- Type of action -->
            <div class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-9">{{ t('TWILIO_TEMPLATES.FORM.ACTION') }}</label>
              <div class="relative">
                <select
                  v-model="action.type"
                  class="w-full text-sm border border-n-weak rounded px-2 py-1.5 pr-8 bg-n-slate-2 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-[#182933] appearance-none"
                >
                  <option value="" disabled>{{ t('TWILIO_TEMPLATES.FORM.SELECT_ACTION_TYPE') }}</option>
                  <option value="QUICK_REPLY">{{ t('TWILIO_TEMPLATES.FORM.ACTION_TYPE_QUICK_REPLY') }}</option>
                  <option value="PHONE_NUMBER">{{ t('TWILIO_TEMPLATES.FORM.ACTION_TYPE_PHONE') }}</option>
                  <option value="URL">{{ t('TWILIO_TEMPLATES.FORM.ACTION_TYPE_URL') }}</option>
                  <option value="VOICE_CALL">{{ t('TWILIO_TEMPLATES.FORM.ACTION_TYPE_VOICE_CALL') }}</option>
                  <option value="COPY_CODE">{{ t('TWILIO_TEMPLATES.FORM.ACTION_TYPE_COUPON_CODE') }}</option>
                </select>

              </div>
            </div>
            <div v-if="action.type !== 'COPY_CODE'" class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-9">
                {{ t('TWILIO_TEMPLATES.FORM.BUTTON_TITLE') }}
                <span class="text-ruby-600 ml-0.5">*</span>
              </label>
              <div class="relative">
                <input
                  v-model="action.title"
                  type="text"
                  maxlength="20"
                  :placeholder="t('TWILIO_TEMPLATES.FORM.BUTTON_TITLE')"
                  class="w-full text-sm border border-n-weak rounded px-2 py-1.5 pr-12 focus:outline-none focus:ring-1 focus:ring-[#182933]"
                />
                <span class="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-n-slate-8">
                  {{ (action.title || '').length }}/20
                </span>
              </div>
            </div>
            <div v-if="action.type === 'QUICK_REPLY'" class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-9">{{ t('TWILIO_TEMPLATES.FORM.BUTTON_ID') }}</label>
              <div class="relative">
                <input
                  v-model="action.id"
                  type="text"
                  maxlength="200"
                  :placeholder="t('TWILIO_TEMPLATES.FORM.BUTTON_ID')"
                  class="w-full text-sm border border-n-weak rounded px-2 py-1.5 pr-16 focus:outline-none focus:ring-1 focus:ring-[#182933]"
                />
                <span class="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-n-slate-8">
                  {{ (action.id || '').length }}/200
                </span>
              </div>
              <p class="text-xs text-n-slate-8">{{ t('TWILIO_TEMPLATES.FORM.BUTTON_ID_HINT') }}</p>
            </div>
            <!-- Phone Number / Voice Call -->
            <div v-else-if="action.type === 'PHONE_NUMBER' || action.type === 'VOICE_CALL'" class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-9">{{ t('TWILIO_TEMPLATES.FORM.ACTION_PHONE') }}</label>
              <input
                v-model="action.phone"
                type="tel"
                :placeholder="t('TWILIO_TEMPLATES.FORM.ACTION_PHONE')"
                class="w-full text-sm border border-n-weak rounded px-2 py-1.5 focus:outline-none focus:ring-1 focus:ring-[#182933]"
              />
              <p v-if="action.type === 'VOICE_CALL'" class="text-xs text-n-slate-8">
                This is a voice call through WhatsApp, not a normal call.
              </p>
            </div>
            <!-- Visit Website -->
            <div v-else-if="action.type === 'URL'" class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-9">{{ t('TWILIO_TEMPLATES.FORM.MEDIA_URL') }}</label>
              <input
                v-model="action.url"
                type="url"
                :placeholder="t('TWILIO_TEMPLATES.FORM.ACTION_URL')"
                class="w-full text-sm border border-n-weak rounded px-2 py-1.5 focus:outline-none focus:ring-1 focus:ring-[#182933]"
              />
            </div>
            <!-- Coupon Code -->
            <div v-else-if="action.type === 'COPY_CODE'" class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-9">{{ t('TWILIO_TEMPLATES.FORM.ACTION_COUPON_CODE') }}</label>
              <div class="relative">
                <input
                  v-model="action.code"
                  type="text"
                  maxlength="15"
                  :placeholder="t('TWILIO_TEMPLATES.FORM.ACTION_COUPON_CODE_PLACEHOLDER')"
                  class="w-full text-sm border border-n-weak rounded px-2 py-1.5 pr-12 focus:outline-none focus:ring-1 focus:ring-[#182933]"
                />
                <span class="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-n-slate-8">
                  {{ (action.code || '').length }}/15
                </span>
              </div>
            </div>
          </div>
          <button
            v-if="form.card_actions.length < 9"
            type="button"
            class="flex items-center gap-1.5 text-xs text-[#182933] hover:text-[#182933]/80 mt-0.5 w-fit"
            @click="addCardAction"
          >
            <Icon icon="i-lucide-plus" class="size-3.5" />
            {{ t('TWILIO_TEMPLATES.FORM.ADD_BUTTON') }}
          </button>
        </div>

        <!-- Quick Reply Buttons -->
        <div v-if="isQuickReply" class="flex flex-col gap-2">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('TWILIO_TEMPLATES.FORM.BUTTONS') }}
            <span class="text-n-slate-9 font-normal ml-1">(max 5)</span>
          </label>
          <div
            v-for="(btn, idx) in form.buttons"
            :key="idx"
            class="flex flex-col gap-2 p-3 border border-n-weak rounded-lg"
          >
            <div class="flex items-center justify-between">
              <span class="text-xs font-medium text-n-slate-10">Button {{ idx + 1 }}</span>
              <button
                type="button"
                class="text-n-slate-8 hover:text-ruby-600 transition-colors"
                @click="removeButton(idx)"
              >
                <Icon icon="i-lucide-trash-2" class="size-3.5" />
              </button>
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-9">
                {{ t('TWILIO_TEMPLATES.FORM.BUTTON_TITLE') }}
                <span class="text-ruby-600 ml-0.5">*</span>
              </label>
              <div class="relative">
                <input
                  v-model="btn.title"
                  type="text"
                  maxlength="20"
                  :placeholder="t('TWILIO_TEMPLATES.FORM.BUTTON_TITLE')"
                  class="w-full text-sm border border-n-weak rounded px-2 py-1.5 pr-12 focus:outline-none focus:ring-1 focus:ring-[#182933]"
                />
                <span class="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-n-slate-8">
                  {{ btn.title.length }}/20
                </span>
              </div>
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-9">{{ t('TWILIO_TEMPLATES.FORM.BUTTON_ID') }}</label>
              <div class="relative">
                <input
                  v-model="btn.id"
                  type="text"
                  maxlength="200"
                  :placeholder="t('TWILIO_TEMPLATES.FORM.BUTTON_ID')"
                  class="w-full text-sm border border-n-weak rounded px-2 py-1.5 pr-16 focus:outline-none focus:ring-1 focus:ring-[#182933]"
                />
                <span class="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-n-slate-8">
                  {{ btn.id.length }}/200
                </span>
              </div>
              <p class="text-xs text-n-slate-8">{{ t('TWILIO_TEMPLATES.FORM.BUTTON_ID_HINT') }}</p>
            </div>
          </div>
          <button
            v-if="form.buttons.length < 10"
            type="button"
            class="flex items-center gap-1.5 text-xs text-[#182933] hover:text-[#182933]/80 mt-0.5 w-fit"
            @click="addButton"
          >
            <Icon icon="i-lucide-plus" class="size-3.5" />
            {{ t('TWILIO_TEMPLATES.FORM.ADD_BUTTON') }}
          </button>
        </div>

        <!-- Call to Action -->
        <div v-if="isCta" class="flex flex-col gap-2">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('TWILIO_TEMPLATES.FORM.ACTIONS') }}
            <span class="text-n-slate-9 font-normal ml-1">(max 2)</span>
          </label>
          <div
            v-for="(action, idx) in form.actions"
            :key="idx"
            class="flex flex-col gap-2 p-3 border border-n-weak rounded-lg"
          >
            <div class="flex items-center justify-between">
              <span class="text-xs font-medium text-n-slate-10">
                {{ t('TWILIO_TEMPLATES.FORM.ACTION') }} {{ idx + 1 }}
              </span>
              <button
                type="button"
                class="text-n-slate-8 hover:text-ruby-600 transition-colors"
                @click="removeAction(idx)"
              >
                <Icon icon="i-lucide-trash-2" class="size-3.5" />
              </button>
            </div>
            <div class="grid grid-cols-2 gap-2">
              <select
                v-model="action.type"
                class="text-sm border border-n-weak rounded px-2 py-1.5 bg-n-slate-2 text-n-slate-12 focus:outline-none"
              >
                <option value="URL">
                  {{ t('TWILIO_TEMPLATES.FORM.ACTION_TYPE_URL') }}
                </option>
                <option value="PHONE_NUMBER">
                  {{ t('TWILIO_TEMPLATES.FORM.ACTION_TYPE_PHONE') }}
                </option>
              </select>
              <input
                v-model="action.title"
                type="text"
                :placeholder="t('TWILIO_TEMPLATES.FORM.ACTION_TITLE')"
                class="text-sm border border-n-weak rounded px-2 py-1.5 focus:outline-none"
              />
            </div>
            <input
              v-if="action.type === 'URL'"
              v-model="action.url"
              type="url"
              :placeholder="t('TWILIO_TEMPLATES.FORM.ACTION_URL')"
              class="w-full text-sm border border-n-weak rounded px-2 py-1.5 focus:outline-none"
            />
            <input
              v-else
              v-model="action.phone"
              type="tel"
              :placeholder="t('TWILIO_TEMPLATES.FORM.ACTION_PHONE')"
              class="w-full text-sm border border-n-weak rounded px-2 py-1.5 focus:outline-none"
            />
          </div>
          <button
            v-if="form.actions.length < 4"
            type="button"
            class="flex items-center gap-1.5 text-xs text-[#182933] hover:text-[#182933]/80 mt-0.5 w-fit"
            @click="addAction"
          >
            <Icon icon="i-lucide-plus" class="size-3.5" />
            {{ t('TWILIO_TEMPLATES.FORM.ADD_ACTION') }}
          </button>
        </div>

        <!-- List Picker -->
        <div v-if="isListPicker" class="flex flex-col gap-3">
          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('TWILIO_TEMPLATES.FORM.LIST_BUTTON') }}
            </label>
            <input
              v-model="form.list_button"
              type="text"
              class="w-full text-sm border border-n-weak rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-[#182933]"
              :placeholder="t('TWILIO_TEMPLATES.FORM.LIST_BUTTON_PLACEHOLDER')"
            />
          </div>
          <div class="flex flex-col gap-2">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('TWILIO_TEMPLATES.FORM.LIST_ITEMS') }}
              <span class="text-n-slate-9 font-normal ml-1">(max 10)</span>
            </label>
            <div
              v-for="(item, idx) in form.list_items"
              :key="idx"
              class="flex flex-col gap-1.5 p-3 border border-n-weak rounded-lg"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs font-medium text-n-slate-10">{{ idx + 1 }}.</span>
                <button
                  type="button"
                  class="text-n-slate-8 hover:text-ruby-600 transition-colors"
                  @click="removeListItem(idx)"
                >
                  <Icon icon="i-lucide-trash-2" class="size-3.5" />
                </button>
              </div>
              <div class="grid grid-cols-2 gap-2">
                <input
                  v-model="item.title"
                  type="text"
                  :placeholder="t('TWILIO_TEMPLATES.FORM.LIST_ITEM_TITLE')"
                  class="text-sm border border-n-weak rounded px-2 py-1.5 focus:outline-none focus:ring-1 focus:ring-[#182933]"
                />
                <input
                  v-model="item.id"
                  type="text"
                  :placeholder="t('TWILIO_TEMPLATES.FORM.LIST_ITEM_ID')"
                  class="text-sm border border-n-weak rounded px-2 py-1.5 focus:outline-none focus:ring-1 focus:ring-[#182933]"
                />
              </div>
              <input
                v-model="item.description"
                type="text"
                :placeholder="t('TWILIO_TEMPLATES.FORM.LIST_ITEM_DESC')"
                class="w-full text-sm border border-n-weak rounded px-2 py-1.5 focus:outline-none focus:ring-1 focus:ring-[#182933]"
              />
            </div>
            <button
              v-if="form.list_items.length < 10"
              type="button"
              class="flex items-center gap-1.5 text-xs text-[#182933] hover:text-[#182933]/80 mt-0.5 w-fit"
              @click="addListItem"
            >
              <Icon icon="i-lucide-plus" class="size-3.5" />
              {{ t('TWILIO_TEMPLATES.FORM.ADD_LIST_ITEM') }}
            </button>
          </div>
        </div>
      </section>

      <!-- Variable Samples -->
      <section v-if="showSamplesStep" class="flex flex-col gap-4">
        <div>
          <h3 class="text-sm font-semibold text-n-slate-12 border-b border-n-weak pb-2">
            {{ t('TWILIO_TEMPLATES.FORM.SAMPLE_VALUES_TITLE') }}
          </h3>
          <p class="text-xs text-n-slate-9 mt-2">
            {{ t('TWILIO_TEMPLATES.FORM.SAMPLE_VALUES_DESC') }}
          </p>
        </div>
        <div class="flex flex-col gap-3">
          <div
            v-for="key in detectedVariableKeys"
            :key="key"
            class="flex flex-col gap-1"
          >
            <label class="text-xs font-medium text-n-slate-11">
              {{ sampleLabel(key) }}
              <span class="text-ruby-600 ml-0.5">*</span>
            </label>
            <input
              v-model="variableSamples[key]"
              type="text"
              :placeholder="sampleLabel(key)"
              class="w-full text-sm border border-n-weak rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-[#182933]"
            />
          </div>
        </div>
      </section>

      <div class="flex justify-end gap-3 pt-2 border-t border-n-weak">
        <button
          type="button"
          class="px-4 py-2 text-sm border border-n-weak rounded-lg hover:bg-n-slate-2 transition-colors"
          @click="showSamplesStep ? (showSamplesStep = false) : close()"
        >
          {{ showSamplesStep ? t('TWILIO_TEMPLATES.FORM.BACK') : t('TWILIO_TEMPLATES.FORM.CANCEL') }}
        </button>
        <button
          type="button"
          class="px-4 py-2 text-sm bg-[#182933] hover:bg-[#182933]/90 text-white dark:bg-n-slate-5 dark:hover:bg-n-slate-6 dark:text-n-slate-12 rounded-lg transition-colors disabled:opacity-50"
          :disabled="isSaving || (!showSamplesStep && !canSave) || (showSamplesStep && !allSamplesFilled)"
          @click="showSamplesStep ? executeSave(variableSamples) : handleSaveClick()"
        >
          {{
            isSaving
              ? t('TWILIO_TEMPLATES.FORM.SAVING')
              : t('TWILIO_TEMPLATES.FORM.SAVE')
          }}
        </button>
      </div>
    </div>
  </woot-modal>
</template>
