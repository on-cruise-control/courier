<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import CounterInput from './CounterInput.vue';
import InfoTip from './InfoTip.vue';
import {
  mapStrings,
  toDisplayVars,
  toStorageVars,
} from 'dashboard/helper/metaTemplateHelper';
import uploadApi from 'dashboard/api/upload';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  show: { type: Boolean, default: false },
  template: { type: Object, default: null },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['update:show', 'onSave']);

const { t } = useI18n();

const CATEGORIES = [
  {
    key: 'text',
    label: t('META_TEMPLATES.CATEGORIES.TEXT'),
    icon: 'i-lucide-type',
    description: t('META_TEMPLATES.CATEGORIES.TEXT_DESCRIPTION'),
  },
  {
    key: 'quick_reply',
    label: t('META_TEMPLATES.CATEGORIES.QUICK_REPLY'),
    icon: 'i-lucide-mouse-pointer-click',
    description: t('META_TEMPLATES.CATEGORIES.QUICK_REPLY_DESCRIPTION'),
  },
  {
    key: 'media',
    label: t('META_TEMPLATES.CATEGORIES.MEDIA'),
    icon: 'i-lucide-image',
    description: t('META_TEMPLATES.CATEGORIES.MEDIA_DESCRIPTION'),
  },
  {
    key: 'call_to_action',
    label: t('META_TEMPLATES.CATEGORIES.CALL_TO_ACTION'),
    icon: 'i-lucide-external-link',
    description: t('META_TEMPLATES.CATEGORIES.CALL_TO_ACTION_DESCRIPTION'),
  },
  {
    key: 'card',
    label: t('META_TEMPLATES.CATEGORIES.CARD'),
    icon: 'i-lucide-layout',
    description: t('META_TEMPLATES.CATEGORIES.CARD_DESCRIPTION'),
  },
];

const MEDIA_UPLOAD_RULES = {
  image: {
    mimeTypes: ['image/png', 'image/jpeg'],
    maxSizeMb: 8,
  },
  video: {
    mimeTypes: [
      'video/mp4',
      'video/ogg',
      'video/x-msvideo',
      'video/quicktime',
      'video/webm',
    ],
    maxSizeMb: 25,
  },
};
const MEDIA_FILE_ACCEPT = [
  ...MEDIA_UPLOAD_RULES.image.mimeTypes,
  ...MEDIA_UPLOAD_RULES.video.mimeTypes,
].join(',');
const CARD_MEDIA_FILE_ACCEPT = MEDIA_UPLOAD_RULES.image.mimeTypes.join(',');

const BUTTON_TYPE_OPTIONS = [
  { value: 'web_url', label: t('META_TEMPLATES.FORM.BUTTON_TYPE_WEB_URL') },
  { value: 'postback', label: t('META_TEMPLATES.FORM.BUTTON_TYPE_POSTBACK') },
];
const NAME_PATTERN = /^[a-z0-9_]+$/;

const emptyForm = () => ({
  name: '',
  category: 'text',
  body: '',
  items: [],
  media_type: 'image',
  media_url: '',
  caption: '',
  ctaText: '',
  ctaButtons: [],
});

const emptyCard = () => ({
  title: '',
  description: '',
  media_url: '',
  actions: [],
  default_action_url: '',
});

const form = ref(emptyForm());

function applySource(tpl) {
  const content = mapStrings(tpl.content || {}, toDisplayVars);
  const base = { name: tpl.name || '', category: tpl.category || 'text' };

  if (tpl.category === 'quick_reply') {
    form.value = {
      ...emptyForm(),
      ...base,
      body: content.body || '',
      items: (content.items || []).map(i => ({
        content_type: 'text',
        title: i.title || '',
        value: i.value || '',
      })),
    };
  } else if (tpl.category === 'media') {
    form.value = {
      ...emptyForm(),
      ...base,
      media_type: content.media_type || 'image',
      media_url: content.media_url || '',
      caption: content.caption || '',
    };
  } else if (tpl.category === 'call_to_action') {
    const item = (content.items || [])[0] || {};
    form.value = {
      ...emptyForm(),
      ...base,
      ctaText: item.text || '',
      ctaButtons: (item.buttons || []).map(b => ({ ...b })),
    };
  } else if (tpl.category === 'card') {
    form.value = {
      ...emptyForm(),
      ...base,
      items: (content.items || []).map(i => ({
        title: i.title || '',
        description: i.description || '',
        media_url: i.media_url || '',
        actions: (i.actions || []).map(a => ({ ...a })),
        default_action_url: i.default_action?.url || '',
      })),
    };
  } else {
    form.value = { ...emptyForm(), ...base, body: content.body || '' };
  }
}

const localShow = ref(props.show);
watch(
  () => props.show,
  visible => {
    localShow.value = visible;
    if (!visible) return;
    if (props.template) applySource(props.template);
    else form.value = emptyForm();
  }
);

function selectCategory(key) {
  form.value = {
    ...emptyForm(),
    name: form.value.name,
    category: key,
    items: key === 'card' ? [emptyCard()] : [],
  };
}

const nameError = computed(() => {
  if (!form.value.name) return null;
  return NAME_PATTERN.test(form.value.name)
    ? null
    : t('META_TEMPLATES.FORM.NAME_INVALID');
});

// Media/card files are uploaded immediately on selection and replaced with
// the resulting Chatwoot-hosted URL — templates never store a file picked
// from the agent's computer directly, only the link to its uploaded copy.
function validateMediaFile(file, { imageOnly = false } = {}) {
  let rules = null;
  if (file.type.startsWith('image/')) rules = MEDIA_UPLOAD_RULES.image;
  else if (!imageOnly && file.type.startsWith('video/')) {
    rules = MEDIA_UPLOAD_RULES.video;
  }

  if (!rules || !rules.mimeTypes.includes(file.type)) {
    return t('META_TEMPLATES.FORM.MEDIA_FILE_TYPE_ERROR');
  }
  if (file.size > rules.maxSizeMb * 1024 * 1024) {
    return t('META_TEMPLATES.FORM.MEDIA_FILE_SIZE_ERROR', {
      max: rules.maxSizeMb,
    });
  }
  return null;
}

// Previews fetch this path directly from the browser, so it must be
// same-origin — a full https://<ngrok host>/... URL trips ngrok's free-tier
// "visitor warning" interstitial on a fresh request and shows as a broken
// image, even though the exact same link works fine for Meta's own fetch.
function toDisplayPath(url) {
  if (!url) return url;
  try {
    const parsed = new URL(url, window.location.origin);
    return `${parsed.pathname}${parsed.search}`;
  } catch {
    return url;
  }
}

const isUploadingMedia = ref(false);
const mediaFileError = ref('');

function removeMediaFile() {
  form.value.media_url = '';
  mediaFileError.value = '';
}

async function handleMediaFileChange(event) {
  const [file] = event.target.files;
  if (!file) return;

  const error = validateMediaFile(file);
  if (error) {
    mediaFileError.value = error;
    return;
  }

  mediaFileError.value = '';
  isUploadingMedia.value = true;
  try {
    const { data } = await uploadApi.createFromFile(file);
    form.value.media_url = data.file_url;
    form.value.media_type = file.type.startsWith('image/') ? 'image' : 'video';
  } catch {
    useAlert(t('META_TEMPLATES.FORM.MEDIA_FILE_UPLOAD_ERROR'));
  } finally {
    isUploadingMedia.value = false;
  }
}

const cardMediaUploading = ref({});
const cardMediaErrors = ref({});

async function handleCardMediaFileChange(idx, event) {
  const [file] = event.target.files;
  if (!file) return;

  const error = validateMediaFile(file, { imageOnly: true });
  if (error) {
    cardMediaErrors.value = { ...cardMediaErrors.value, [idx]: error };
    return;
  }

  cardMediaErrors.value = { ...cardMediaErrors.value, [idx]: '' };
  cardMediaUploading.value = { ...cardMediaUploading.value, [idx]: true };
  try {
    const { data } = await uploadApi.createFromFile(file);
    form.value.items[idx].media_url = data.file_url;
  } catch {
    useAlert(t('META_TEMPLATES.FORM.MEDIA_FILE_UPLOAD_ERROR'));
  } finally {
    cardMediaUploading.value = { ...cardMediaUploading.value, [idx]: false };
  }
}
function removeCardMediaFile(idx) {
  form.value.items[idx].media_url = '';
  cardMediaErrors.value = { ...cardMediaErrors.value, [idx]: '' };
}

// Quick reply items — Meta's text quick reply is the only type we expose; the
// content_type field still exists on the payload for forward-compatibility.
function addQuickReply() {
  if (form.value.items.length < 13)
    form.value.items.push({ content_type: 'text', title: '', value: '' });
}
function removeQuickReply(idx) {
  form.value.items.splice(idx, 1);
}

// Call to action buttons
function addCtaButton() {
  if (form.value.ctaButtons.length < 3)
    form.value.ctaButtons.push({
      type: 'web_url',
      title: '',
      uri: '',
      payload: '',
    });
}
function removeCtaButton(idx) {
  form.value.ctaButtons.splice(idx, 1);
}

// Card items
function addCard() {
  if (form.value.items.length < 10) form.value.items.push(emptyCard());
}
function removeCard(idx) {
  form.value.items.splice(idx, 1);
}
function addCardAction(cardIdx) {
  const actions = form.value.items[cardIdx].actions;
  if (actions.length < 3)
    actions.push({ type: 'postback', text: '', uri: '', payload: '' });
}
function removeCardAction(cardIdx, actionIdx) {
  form.value.items[cardIdx].actions.splice(actionIdx, 1);
}

// Buttons (CTA buttons and Card actions) carry a single value that maps to
// either `uri` (web_url) or `payload` (postback) depending on the selected
// type, so the form only ever shows one input instead of switching fields.
function buttonValue(button) {
  return button.type === 'web_url' ? button.uri : button.payload;
}
function setButtonValue(button, value) {
  if (button.type === 'web_url') button.uri = value;
  else button.payload = value;
}

const canSave = computed(() => {
  if (!form.value.name || nameError.value || props.isSaving) return false;
  if (form.value.category === 'text') return !!form.value.body;
  if (form.value.category === 'quick_reply') {
    return !!form.value.body && form.value.items.length > 0;
  }
  if (form.value.category === 'media') {
    return !!form.value.media_url && !isUploadingMedia.value;
  }
  if (form.value.category === 'call_to_action') {
    return !!form.value.ctaText && form.value.ctaButtons.length > 0;
  }
  if (form.value.category === 'card') {
    return (
      form.value.items.length > 0 &&
      !Object.values(cardMediaUploading.value).some(Boolean)
    );
  }
  return false;
});

// Postback buttons only collect a title/text in the form — the payload the
// backend sends on click just mirrors that same text, same as quick replies.
function normalizeCtaButtons(buttons) {
  return buttons.map(button =>
    button.type === 'postback'
      ? { type: button.type, title: button.title, payload: button.title }
      : { type: button.type, title: button.title, uri: button.uri }
  );
}
function normalizeCardActions(actions) {
  return actions.map(action =>
    action.type === 'postback'
      ? { type: action.type, text: action.text, payload: action.text }
      : { type: action.type, text: action.text, uri: action.uri }
  );
}

function buildContent() {
  if (form.value.category === 'text') return { body: form.value.body };
  if (form.value.category === 'quick_reply') {
    return { body: form.value.body, items: form.value.items };
  }
  if (form.value.category === 'media') {
    return {
      media_type: form.value.media_type,
      media_url: form.value.media_url,
      caption: form.value.caption,
    };
  }
  if (form.value.category === 'call_to_action') {
    return {
      items: [
        {
          text: form.value.ctaText,
          buttons: normalizeCtaButtons(form.value.ctaButtons),
        },
      ],
    };
  }
  if (form.value.category === 'card') {
    return {
      items: form.value.items.map(item => ({
        title: item.title,
        description: item.description,
        media_url: item.media_url,
        actions: normalizeCardActions(item.actions),
        ...(item.default_action_url
          ? {
              default_action: { type: 'web_url', url: item.default_action_url },
            }
          : {}),
      })),
    };
  }
  return {};
}

function handleSave() {
  if (!canSave.value) return;

  emit('onSave', {
    name: form.value.name.trim(),
    category: form.value.category,
    content: mapStrings(buildContent(), value => toStorageVars(value.trim())),
  });
}

function close() {
  localShow.value = false;
  emit('update:show', false);
}
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="close" size="medium">
    <woot-modal-header
      :header-title="
        template
          ? t('META_TEMPLATES.MODAL.EDIT_TITLE')
          : t('META_TEMPLATES.MODAL.CREATE_TITLE')
      "
    />

    <div
      class="px-4 sm:px-8 pb-8 flex flex-col gap-6 overflow-y-auto max-h-[75vh]"
    >
      <!-- General Information -->
      <section class="flex flex-col gap-3">
        <h3
          class="text-sm font-semibold text-n-slate-12 border-b border-n-weak pb-2"
        >
          {{ t('META_TEMPLATES.FORM.GENERAL_INFO') }}
        </h3>
        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('META_TEMPLATES.FORM.NAME') }}
            <span class="text-n-ruby-9 ml-0.5">*</span>
          </label>
          <input
            v-model="form.name"
            type="text"
            maxlength="450"
            class="w-full text-sm border rounded-lg px-3 py-2 bg-transparent"
            :class="nameError ? 'border-n-ruby-9' : 'border-n-weak'"
            :placeholder="t('META_TEMPLATES.FORM.NAME_PLACEHOLDER')"
          />
          <p v-if="nameError" class="text-xs text-n-ruby-9">
            {{ nameError }}
          </p>
          <p v-else class="text-xs text-n-slate-9">
            {{ t('META_TEMPLATES.FORM.NAME_HINT') }}
          </p>
        </div>
      </section>

      <!-- Content Type -->
      <section v-if="!template" class="flex flex-col gap-3">
        <h3
          class="text-sm font-semibold text-n-slate-12 border-b border-n-weak pb-2"
        >
          {{ t('META_TEMPLATES.FORM.CONTENT_TYPE') }}
        </h3>
        <div class="grid grid-cols-2 gap-2">
          <button
            v-for="cat in CATEGORIES"
            :key="cat.key"
            type="button"
            class="flex items-center gap-3 px-4 py-3 border rounded-lg transition-colors text-left"
            :class="
              form.category === cat.key
                ? 'border-[#182933] bg-[#182933]/10 text-[#182933] ring-1 ring-[#182933]/40 dark:border-n-slate-6 dark:bg-n-slate-4 dark:text-n-slate-12 dark:ring-n-slate-6'
                : 'border-n-weak text-n-slate-11 hover:border-[#182933]/30 hover:bg-[#182933]/5 dark:hover:border-n-slate-6 dark:hover:bg-n-slate-3'
            "
            @click="selectCategory(cat.key)"
          >
            <div
              class="size-7 rounded flex items-center justify-center shrink-0"
              :class="
                form.category === cat.key
                  ? 'bg-[#182933]/20 dark:bg-n-slate-6'
                  : 'bg-n-slate-3'
              "
            >
              <Icon :icon="cat.icon" class="size-4" />
            </div>
            <span class="text-sm font-medium flex-1">{{ cat.label }}</span>
            <span
              v-if="form.category === cat.key"
              v-tooltip="{
                content: cat.description,
                placement: 'top',
                popperClass: 'meta-template-category-tooltip',
              }"
              class="shrink-0 text-n-slate-9 hover:text-n-slate-12"
              @click.stop
            >
              <Icon icon="i-lucide-info" class="size-3.5" />
            </span>
          </button>
        </div>
      </section>

      <!-- Configure Content -->
      <section class="flex flex-col gap-3">
        <h3
          class="text-sm font-semibold text-n-slate-12 border-b border-n-weak pb-2"
        >
          {{ t('META_TEMPLATES.FORM.CONFIGURE_CONTENT') }}
        </h3>

        <!-- Text -->
        <div v-if="form.category === 'text'" class="flex flex-col gap-1">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('META_TEMPLATES.FORM.BODY') }}
            <InfoTip :text="t('META_TEMPLATES.TOOLTIPS.VARIABLES')" />
          </label>
          <CounterInput
            v-model="form.body"
            multiline
            :rows="3"
            :maxlength="1000"
            :placeholder="t('META_TEMPLATES.FORM.BODY_PLACEHOLDER')"
          />
          <p class="text-xs text-n-slate-9">
            {{ t('META_TEMPLATES.FORM.BODY_HINT') }}
          </p>
        </div>

        <!-- Quick Reply -->
        <div v-if="form.category === 'quick_reply'" class="flex flex-col gap-3">
          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('META_TEMPLATES.FORM.BODY') }}
              <InfoTip :text="t('META_TEMPLATES.TOOLTIPS.VARIABLES')" />
            </label>
            <CounterInput
              v-model="form.body"
              multiline
              :maxlength="1000"
              :placeholder="t('META_TEMPLATES.FORM.BODY_PLACEHOLDER')"
            />
            <p class="text-xs text-n-slate-9">
              {{ t('META_TEMPLATES.FORM.BODY_HINT') }}
            </p>
          </div>
          <div>
            <div class="flex items-center justify-between mb-1.5">
              <label class="text-xs font-medium text-n-slate-11">
                {{ t('META_TEMPLATES.FORM.QUICK_REPLIES') }}
                {{
                  t('META_TEMPLATES.FORM.COUNT', {
                    count: form.items.length,
                    max: 13,
                  })
                }}
              </label>
              <button
                v-tooltip.top="t('META_TEMPLATES.TOOLTIPS.ADD_QUICK_REPLY')"
                type="button"
                class="text-xs text-n-brand font-medium disabled:opacity-40"
                :disabled="form.items.length >= 13"
                @click="addQuickReply"
              >
                + {{ t('META_TEMPLATES.FORM.ADD') }}
              </button>
            </div>
            <div
              v-for="(item, idx) in form.items"
              :key="idx"
              class="flex items-center gap-2 mb-2"
            >
              <CounterInput
                v-model="item.title"
                :maxlength="20"
                class="flex-1"
                :placeholder="t('META_TEMPLATES.FORM.QUICK_REPLY_TITLE')"
              />
              <button
                v-tooltip.top="t('META_TEMPLATES.TOOLTIPS.REMOVE_QUICK_REPLY')"
                type="button"
                class="shrink-0 text-n-slate-9 hover:text-red-600"
                @click="removeQuickReply(idx)"
              >
                <Icon icon="i-lucide-trash-2" class="size-4" />
              </button>
            </div>
          </div>
        </div>

        <!-- Media -->
        <div v-if="form.category === 'media'" class="flex flex-col gap-3">
          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-n-slate-11">{{
              t('META_TEMPLATES.FORM.MEDIA_FILE')
            }}</label>
            <div class="flex items-center gap-3">
              <label
                v-tooltip.top="t('META_TEMPLATES.TOOLTIPS.SELECT_FILE')"
                class="inline-flex items-center px-3 py-1.5 rounded-lg bg-n-slate-3 text-n-slate-12 text-sm font-medium cursor-pointer hover:bg-n-slate-4"
                :class="{ 'opacity-50 cursor-not-allowed': isUploadingMedia }"
              >
                {{ t('META_TEMPLATES.FORM.MEDIA_FILE_SELECT') }}
                <input
                  type="file"
                  :accept="MEDIA_FILE_ACCEPT"
                  :disabled="isUploadingMedia"
                  class="hidden"
                  @change="handleMediaFileChange"
                />
              </label>
              <button
                v-if="form.media_url && !isUploadingMedia"
                type="button"
                class="text-sm font-medium text-n-ruby-9 hover:text-n-ruby-10"
                @click="removeMediaFile"
              >
                {{ t('META_TEMPLATES.FORM.MEDIA_FILE_REMOVE') }}
              </button>
            </div>
            <p class="text-xs text-n-slate-9">
              {{ t('META_TEMPLATES.FORM.MEDIA_FILE_HINT') }}
            </p>
            <p v-if="isUploadingMedia" class="text-xs text-n-slate-9">
              {{ t('META_TEMPLATES.FORM.MEDIA_FILE_UPLOADING') }}
            </p>
            <p v-else-if="mediaFileError" class="text-xs text-n-ruby-9">
              {{ mediaFileError }}
            </p>
            <img
              v-else-if="form.media_url && form.media_type === 'image'"
              :src="toDisplayPath(form.media_url)"
              class="size-12 rounded-md object-cover border border-n-weak"
            />
            <video
              v-else-if="form.media_url"
              :src="toDisplayPath(form.media_url)"
              class="size-12 rounded-md object-cover border border-n-weak"
              muted
            />
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('META_TEMPLATES.FORM.BODY') }}
              <InfoTip :text="t('META_TEMPLATES.TOOLTIPS.VARIABLES')" />
            </label>
            <CounterInput v-model="form.caption" multiline :maxlength="1000" />
            <p class="text-xs text-n-slate-9">
              {{ t('META_TEMPLATES.FORM.BODY_HINT') }}
            </p>
          </div>
        </div>

        <!-- Call to Action -->
        <div
          v-if="form.category === 'call_to_action'"
          class="flex flex-col gap-3"
        >
          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('META_TEMPLATES.FORM.BODY') }}
              <InfoTip :text="t('META_TEMPLATES.TOOLTIPS.VARIABLES')" />
            </label>
            <CounterInput
              v-model="form.ctaText"
              multiline
              :maxlength="640"
              :placeholder="t('META_TEMPLATES.FORM.BODY_PLACEHOLDER')"
            />
            <p class="text-xs text-n-slate-9">
              {{ t('META_TEMPLATES.FORM.BODY_HINT') }}
            </p>
          </div>
          <div>
            <div class="flex items-center justify-between mb-1.5">
              <label class="text-xs font-medium text-n-slate-11">
                {{ t('META_TEMPLATES.FORM.BUTTONS') }}
                {{
                  t('META_TEMPLATES.FORM.COUNT', {
                    count: form.ctaButtons.length,
                    max: 3,
                  })
                }}
              </label>
              <button
                v-tooltip.top="t('META_TEMPLATES.TOOLTIPS.ADD_BUTTON')"
                type="button"
                class="text-xs text-n-brand font-medium disabled:opacity-40"
                :disabled="form.ctaButtons.length >= 3"
                @click="addCtaButton"
              >
                + {{ t('META_TEMPLATES.FORM.ADD') }}
              </button>
            </div>
            <div
              v-for="(button, idx) in form.ctaButtons"
              :key="idx"
              class="flex flex-col gap-1.5 mb-2 p-2 rounded-lg border border-n-weak"
            >
              <div class="flex items-center justify-between">
                <Select v-model="button.type" :options="BUTTON_TYPE_OPTIONS" />
                <button
                  v-tooltip.top="t('META_TEMPLATES.TOOLTIPS.REMOVE_BUTTON')"
                  type="button"
                  class="text-n-slate-9 hover:text-red-600"
                  @click="removeCtaButton(idx)"
                >
                  <Icon icon="i-lucide-trash-2" class="size-4" />
                </button>
              </div>
              <CounterInput
                v-model="button.title"
                :maxlength="20"
                :placeholder="t('META_TEMPLATES.FORM.BUTTON_TITLE')"
              />
              <CounterInput
                v-if="button.type === 'web_url'"
                :model-value="buttonValue(button)"
                :maxlength="1000"
                :placeholder="t('META_TEMPLATES.FORM.BUTTON_URL_PLACEHOLDER')"
                @update:model-value="val => setButtonValue(button, val)"
              />
            </div>
          </div>
        </div>

        <!-- Card -->
        <div v-if="form.category === 'card'" class="flex flex-col gap-3">
          <div class="flex items-center justify-between">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('META_TEMPLATES.FORM.CARDS') }}
              {{
                t('META_TEMPLATES.FORM.COUNT', {
                  count: form.items.length,
                  max: 10,
                })
              }}
            </label>
            <button
              v-tooltip.top="t('META_TEMPLATES.TOOLTIPS.ADD_CARD')"
              type="button"
              class="text-xs text-n-brand font-medium disabled:opacity-40"
              :disabled="form.items.length >= 10"
              @click="addCard"
            >
              + {{ t('META_TEMPLATES.FORM.ADD') }}
            </button>
          </div>
          <div
            v-for="(item, idx) in form.items"
            :key="idx"
            class="flex flex-col gap-2 p-3 rounded-lg border border-n-weak"
          >
            <div class="flex items-center justify-between">
              <span class="text-xs font-medium text-n-slate-9">
                {{ t('META_TEMPLATES.FORM.CARD') }} {{ idx + 1 }}
              </span>
              <button
                v-if="form.items.length > 1"
                v-tooltip.top="t('META_TEMPLATES.TOOLTIPS.REMOVE_CARD')"
                type="button"
                class="text-n-slate-9 hover:text-red-600"
                @click="removeCard(idx)"
              >
                <Icon icon="i-lucide-trash-2" class="size-4" />
              </button>
            </div>
            <CounterInput
              v-model="item.title"
              :maxlength="80"
              :placeholder="t('META_TEMPLATES.FORM.CARD_TITLE')"
            />
            <CounterInput
              v-model="item.description"
              :maxlength="80"
              :placeholder="t('META_TEMPLATES.FORM.CARD_SUBTITLE')"
            />
            <div class="flex items-center gap-3">
              <label
                v-tooltip.top="t('META_TEMPLATES.TOOLTIPS.SELECT_CARD_IMAGE')"
                class="inline-flex items-center px-3 py-1.5 rounded-lg bg-n-slate-3 text-n-slate-12 text-sm font-medium cursor-pointer hover:bg-n-slate-4"
                :class="{
                  'opacity-50 cursor-not-allowed': cardMediaUploading[idx],
                }"
              >
                {{ t('META_TEMPLATES.FORM.MEDIA_FILE_SELECT') }}
                <input
                  type="file"
                  :accept="CARD_MEDIA_FILE_ACCEPT"
                  :disabled="cardMediaUploading[idx]"
                  class="hidden"
                  @change="e => handleCardMediaFileChange(idx, e)"
                />
              </label>
              <button
                v-if="item.media_url && !cardMediaUploading[idx]"
                type="button"
                class="text-sm font-medium text-n-ruby-9 hover:text-n-ruby-10"
                @click="removeCardMediaFile(idx)"
              >
                {{ t('META_TEMPLATES.FORM.MEDIA_FILE_REMOVE') }}
              </button>
            </div>
            <p class="text-xs text-n-slate-9">
              {{ t('META_TEMPLATES.FORM.CARD_MEDIA_HINT') }}
            </p>
            <p v-if="cardMediaUploading[idx]" class="text-xs text-n-slate-9">
              {{ t('META_TEMPLATES.FORM.MEDIA_FILE_UPLOADING') }}
            </p>
            <p v-else-if="cardMediaErrors[idx]" class="text-xs text-n-ruby-9">
              {{ cardMediaErrors[idx] }}
            </p>
            <img
              v-else-if="item.media_url"
              :src="toDisplayPath(item.media_url)"
              class="size-12 rounded-md object-cover border border-n-weak"
            />
            <div class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-9">
                {{ t('META_TEMPLATES.FORM.DEFAULT_ACTION_URL') }}
              </label>
              <input
                v-model="item.default_action_url"
                type="url"
                class="w-full rounded-lg border border-n-weak bg-transparent px-3 py-1.5 text-sm"
                :placeholder="t('META_TEMPLATES.FORM.BUTTON_VALUE_PLACEHOLDER')"
              />
              <p class="text-xs text-n-slate-9">
                {{ t('META_TEMPLATES.FORM.DEFAULT_ACTION_URL_HINT') }}
              </p>
            </div>
            <div>
              <div class="flex items-center justify-between mb-1">
                <span class="text-xs text-n-slate-9">
                  {{ t('META_TEMPLATES.FORM.BUTTONS') }}
                  {{
                    t('META_TEMPLATES.FORM.COUNT', {
                      count: item.actions.length,
                      max: 3,
                    })
                  }}
                </span>
                <button
                  v-tooltip.top="t('META_TEMPLATES.TOOLTIPS.ADD_CARD_BUTTON')"
                  type="button"
                  class="text-xs text-n-brand font-medium disabled:opacity-40"
                  :disabled="item.actions.length >= 3"
                  @click="addCardAction(idx)"
                >
                  + {{ t('META_TEMPLATES.FORM.ADD') }}
                </button>
              </div>
              <div
                v-for="(action, aIdx) in item.actions"
                :key="aIdx"
                class="flex flex-col gap-1.5 mb-1.5 p-2 rounded-lg border border-n-weak"
              >
                <div class="flex items-center justify-between">
                  <Select
                    v-model="action.type"
                    :options="BUTTON_TYPE_OPTIONS"
                  />
                  <button
                    v-tooltip.top="t('META_TEMPLATES.TOOLTIPS.REMOVE_BUTTON')"
                    type="button"
                    class="text-n-slate-9 hover:text-red-600"
                    @click="removeCardAction(idx, aIdx)"
                  >
                    <Icon icon="i-lucide-trash-2" class="size-4" />
                  </button>
                </div>
                <CounterInput
                  v-model="action.text"
                  :maxlength="20"
                  :placeholder="t('META_TEMPLATES.FORM.BUTTON_TITLE')"
                />
                <CounterInput
                  v-if="action.type === 'web_url'"
                  :model-value="buttonValue(action)"
                  :maxlength="1000"
                  :placeholder="t('META_TEMPLATES.FORM.BUTTON_URL_PLACEHOLDER')"
                  @update:model-value="val => setButtonValue(action, val)"
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      <div
        class="flex items-center justify-end gap-3 pt-3 border-t border-n-weak"
      >
        <button
          class="px-3 py-2 text-sm text-n-slate-11 hover:bg-n-slate-2 rounded-lg"
          @click="close"
        >
          {{ t('META_TEMPLATES.FORM.CANCEL') }}
        </button>
        <button
          class="px-4 py-2 text-sm bg-n-brand hover:bg-n-brand/90 text-white rounded-lg disabled:opacity-50"
          :disabled="!canSave"
          @click="handleSave"
        >
          {{
            isSaving
              ? t('META_TEMPLATES.FORM.SAVING')
              : t('META_TEMPLATES.FORM.SAVE')
          }}
        </button>
      </div>
    </div>
  </woot-modal>
</template>
