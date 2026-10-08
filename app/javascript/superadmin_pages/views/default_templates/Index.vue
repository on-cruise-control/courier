<script setup>
import { computed, nextTick, ref } from 'vue';
import {
  mapStrings,
  toDisplayVars,
  toStorageVars,
} from 'dashboard/helper/metaTemplateHelper';

const props = defineProps({
  componentData: { type: Object, default: () => ({}) },
});

const PLATFORMS = [
  { key: 'all', label: 'Universal' },
  { key: 'whatsapp', label: 'WhatsApp' },
  { key: 'facebook', label: 'Facebook' },
  { key: 'instagram', label: 'Instagram' },
];

const CATEGORIES = [
  { key: 'text', label: 'Text' },
  { key: 'quick_reply', label: 'Quick reply' },
  { key: 'media', label: 'Media' },
  { key: 'call_to_action', label: 'Call to action' },
  { key: 'card', label: 'Card' },
];

// WhatsApp (Twilio) is stricter, so shared templates follow its limits.
const STRICT = {
  quickReplies: 3,
  buttons: 2,
  cards: 1,
  body: 1024,
  quickReplyTitle: 20,
  buttonTitle: 25,
  buttonTypes: ['web_url'],
};
const META = {
  quickReplies: 13,
  buttons: 3,
  cards: 10,
  body: 2000,
  quickReplyTitle: 20,
  buttonTitle: 640,
  buttonTypes: ['web_url', 'postback'],
};
const limitsFor = platform =>
  platform === 'facebook' || platform === 'instagram' ? META : STRICT;

const BUTTON_TYPE_LABELS = { web_url: 'Link (URL)', postback: 'Reply' };
const MEDIA_RULES = {
  image: { mimeTypes: ['image/png', 'image/jpeg'], maxSizeMb: 8 },
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
const MEDIA_ACCEPT = [
  ...MEDIA_RULES.image.mimeTypes,
  ...MEDIA_RULES.video.mimeTypes,
].join(',');
const IMAGE_ACCEPT = MEDIA_RULES.image.mimeTypes.join(',');

const HINTS = {
  language: 'Language code of the template, for example en.',
  name: 'Use only lowercase letters, numbers and underscores, for example order_ready. Shown in the inbox template list.',
  variables:
    'Use {var1}, {var2} for values that change. They are filled in when the template is sent.',
  quickReplyTitle: 'Button label shown to the customer (max 20 characters).',
  buttonTitle: 'Text shown on the button.',
  buttonUrl: 'Link opened when the customer taps the button.',
  buttonReply: 'Tapping the button sends this text back as the customer reply.',
  cardTitle: 'Heading of the card.',
  cardDescription: 'Short text under the card heading.',
  defaultAction: 'Optional. Link opened when the customer taps the card.',
  caption: 'Optional text sent along with the media.',
};
const NAME_PATTERN = /^[a-z0-9_]+$/;
const NAME_ERROR =
  'Name can only contain lowercase letters, numbers and underscores (no capitals or spaces)';
const buttonPlaceholder = button =>
  button.type === 'web_url' ? 'Visit website' : 'Yes, I am interested';
const VAR_PLACEHOLDER = 'Hi {var1}, your order {var2} is ready';

const templates = ref(props.componentData.templates || []);
const settings = ref(props.componentData.settings || {});
const activeTab = ref('all');
const showForm = ref(false);
const viewing = ref(null);
const editingId = ref(null);
const serverErrors = ref([]);
const isSaving = ref(false);
const showErrors = ref(false);

const visibleTemplates = computed(() =>
  templates.value.filter(t => t.platform === activeTab.value)
);
const countFor = key => templates.value.filter(t => t.platform === key).length;
const labelFor = (list, key) => list.find(i => i.key === key)?.label || key;

const csrfToken = () =>
  document.querySelector('meta[name="csrf-token"]')?.content;

const request = async (url, method, body) => {
  const isForm = body instanceof FormData;
  const headers = { Accept: 'application/json', 'X-CSRF-Token': csrfToken() };
  if (!isForm) headers['Content-Type'] = 'application/json';
  const response = await fetch(url, {
    method,
    headers,
    body: isForm || !body ? body : JSON.stringify(body),
  });
  const data = await response.json().catch(() => ({}));
  return { ok: response.ok, data };
};

const SETTING_OPTIONS = [
  {
    key: 'auto_sync_on_inbox_create',
    label: 'Auto sync when an inbox is created',
  },
  {
    key: 'auto_sync_on_template_change',
    label: 'Auto sync when a default template is created, updated or deleted',
  },
];

const updateSetting = async (key, value) => {
  const { ok, data } = await request(
    '/super_admin/default_templates/settings',
    'PUT',
    { [key]: value }
  );
  if (ok) settings.value = data.settings;
};

const emptyButton = () => ({ type: 'web_url', title: '', uri: '' });
const emptyCard = () => ({
  title: '',
  description: '',
  media_url: '',
  default_action_url: '',
  actions: [],
});
const emptyForm = (platform = activeTab.value) => ({
  name: '',
  platform,
  category: 'text',
  language: 'en',
  body: '',
  items: [],
  media_type: 'image',
  media_url: '',
  caption: '',
  ctaText: '',
  ctaButtons: [],
});
const form = ref(emptyForm());

const limits = computed(() => limitsFor(form.value.platform));
const isStrict = computed(() => limits.value === STRICT);
const buttonTypes = computed(() => limits.value.buttonTypes);

const selectCategory = key => {
  form.value = {
    ...emptyForm(form.value.platform),
    name: form.value.name,
    language: form.value.language,
    category: key,
    items: key === 'card' ? [emptyCard()] : [],
  };
  showErrors.value = false;
};

const changePlatform = () => selectCategory(form.value.category);

const openCreate = () => {
  editingId.value = null;
  serverErrors.value = [];
  showErrors.value = false;
  form.value = emptyForm();
  showForm.value = true;
};

const toButton = b => ({
  type: b.type || 'web_url',
  title: b.title || b.text || '',
  uri: b.uri || '',
});

const openEdit = template => {
  const content = mapStrings(template.content || {}, toDisplayVars);
  const base = {
    ...emptyForm(template.platform),
    name: template.name,
    category: template.category,
    language: template.language,
  };
  const item = (content.items || [])[0] || {};
  const byCategory = {
    text: { body: content.body || '' },
    quick_reply: {
      body: content.body || '',
      items: (content.items || []).map(i => ({
        title: i.title || '',
      })),
    },
    media: {
      media_type: content.media_type || 'image',
      media_url: content.media_url || '',
      caption: content.caption || '',
    },
    call_to_action: {
      ctaText: item.text || '',
      ctaButtons: (item.buttons || []).map(toButton),
    },
    card: {
      items: (content.items || []).map(i => ({
        title: i.title || '',
        description: i.description || '',
        media_url: i.media_url || '',
        default_action_url: i.default_action?.url || '',
        actions: (i.actions || []).map(toButton),
      })),
    },
  };
  editingId.value = template.id;
  serverErrors.value = [];
  showErrors.value = false;
  form.value = { ...base, ...byCategory[template.category] };
  showForm.value = true;
};

// Reply buttons only collect a title; the payload sent back mirrors it.
const ctaButtonPayload = b =>
  b.type === 'web_url'
    ? { type: 'web_url', title: b.title, uri: b.uri }
    : { type: 'postback', title: b.title, payload: b.title };
const cardActionPayload = b =>
  b.type === 'web_url'
    ? { type: 'web_url', text: b.title, uri: b.uri }
    : { type: 'postback', text: b.title, payload: b.title };

const buildContent = () => {
  const f = form.value;
  let content;
  if (f.category === 'quick_reply') {
    content = {
      body: f.body,
      items: f.items.map(i => ({
        content_type: 'text',
        title: i.title,
        value: i.title,
      })),
    };
  } else if (f.category === 'media') {
    content = {
      media_type: f.media_type,
      media_url: f.media_url,
      caption: f.caption,
    };
  } else if (f.category === 'call_to_action') {
    content = {
      items: [{ text: f.ctaText, buttons: f.ctaButtons.map(ctaButtonPayload) }],
    };
  } else if (f.category === 'card') {
    content = {
      items: f.items.map(i => {
        const card = {
          title: i.title,
          description: i.description,
          media_url: i.media_url,
          actions: i.actions.map(cardActionPayload),
        };
        if (i.default_action_url) {
          card.default_action = { type: 'web_url', url: i.default_action_url };
        }
        return card;
      }),
    };
  } else {
    content = { body: f.body };
  }
  return mapStrings(content, toStorageVars);
};

const validateButtons = (buttons, label) => {
  const l = limits.value;
  const found = [];
  const add = message => found.push({ field: 'general', message });
  if (buttons.length > l.buttons) {
    add(`${label}: at most ${l.buttons} buttons are allowed`);
  }
  buttons.forEach((b, idx) => {
    if (!b.title) add(`${label} button ${idx + 1}: title is required`);
    if (b.title.length > l.buttonTitle) {
      add(
        `${label} button ${idx + 1}: title must be at most ${l.buttonTitle} characters`
      );
    }
    if (b.type === 'web_url' && !b.uri) {
      add(`${label} button ${idx + 1}: URL is required`);
    }
  });
  return found;
};

const errors = computed(() => {
  const f = form.value;
  const l = limits.value;
  const list = [];
  const add = (field, message) => list.push({ field, message });
  if (!f.name.trim()) add('name', 'Name is required');
  else if (!NAME_PATTERN.test(f.name)) add('name', NAME_ERROR);
  const bodyCheck = (text, label) => {
    if (!text) add('body', `${label} is required`);
    else if (text.length > l.body) {
      add('body', `${label} must be at most ${l.body} characters`);
    }
  };
  if (f.category === 'text') bodyCheck(f.body, 'Body');
  if (f.category === 'quick_reply') {
    bodyCheck(f.body, 'Body');
    if (!f.items.length) add('general', 'At least one quick reply is required');
    if (f.items.length > l.quickReplies) {
      add('general', `At most ${l.quickReplies} quick replies are allowed`);
    }
    f.items.forEach((i, idx) => {
      if (!i.title) add('general', `Quick reply ${idx + 1}: title is required`);
      if (i.title.length > l.quickReplyTitle) {
        add(
          'general',
          `Quick reply ${idx + 1}: title must be at most ${l.quickReplyTitle} characters`
        );
      }
    });
  }
  if (f.category === 'media' && !f.media_url) {
    add('media', 'Upload an image or video');
  }
  if (f.category === 'call_to_action') {
    bodyCheck(f.ctaText, 'Text');
    if (!f.ctaButtons.length) add('general', 'At least one button is required');
    list.push(...validateButtons(f.ctaButtons, 'Call to action'));
  }
  if (f.category === 'card') {
    if (!f.items.length) add('general', 'At least one card is required');
    if (f.items.length > l.cards) {
      add(
        'general',
        `At most ${l.cards} card${l.cards > 1 ? 's' : ''} allowed`
      );
    }
    f.items.forEach((i, idx) => {
      if (!i.title) add('general', `Card ${idx + 1}: title is required`);
      list.push(...validateButtons(i.actions, `Card ${idx + 1}`));
    });
  }
  return list;
});

const fieldError = field =>
  showErrors.value
    ? errors.value.find(e => e.field === field)?.message
    : undefined;
// A badly formatted name is reported as soon as it is typed.
const nameError = computed(() =>
  form.value.name && !NAME_PATTERN.test(form.value.name)
    ? NAME_ERROR
    : fieldError('name')
);
const generalErrors = computed(() =>
  showErrors.value ? errors.value.filter(e => e.field === 'general') : []
);

const uploading = ref({});
const uploadErrors = ref({});

const uploadFile = async (slot, event, { imageOnly = false } = {}) => {
  const [file] = event.target.files;
  event.target.value = '';
  if (!file) return null;
  const rules = Object.entries(MEDIA_RULES).find(
    ([type, rule]) =>
      (!imageOnly || type === 'image') && rule.mimeTypes.includes(file.type)
  )?.[1];
  if (!rules) {
    uploadErrors.value = {
      ...uploadErrors.value,
      [slot]: imageOnly
        ? 'Only PNG or JPEG images are allowed'
        : 'Only PNG, JPEG or video files are allowed',
    };
    return null;
  }
  if (file.size > rules.maxSizeMb * 1024 * 1024) {
    uploadErrors.value = {
      ...uploadErrors.value,
      [slot]: `File must be smaller than ${rules.maxSizeMb} MB`,
    };
    return null;
  }
  uploadErrors.value = { ...uploadErrors.value, [slot]: '' };
  uploading.value = { ...uploading.value, [slot]: true };
  const formData = new FormData();
  formData.append('attachment', file);
  if (imageOnly) formData.append('image_only', true);
  const { ok, data } = await request(
    '/super_admin/default_templates/upload',
    'POST',
    formData
  );
  uploading.value = { ...uploading.value, [slot]: false };
  if (!ok) {
    uploadErrors.value = {
      ...uploadErrors.value,
      [slot]: data.error || 'Upload failed',
    };
    return null;
  }
  return { url: data.file_url, isImage: file.type.startsWith('image/') };
};

const onMediaChange = async event => {
  const uploaded = await uploadFile('media', event);
  if (!uploaded) return;
  form.value.media_url = uploaded.url;
  form.value.media_type = uploaded.isImage ? 'image' : 'video';
};

const onCardMediaChange = async (idx, event) => {
  const uploaded = await uploadFile(`card-${idx}`, event, { imageOnly: true });
  if (uploaded) form.value.items[idx].media_url = uploaded.url;
};

const viewContent = computed(() =>
  mapStrings(viewing.value?.content || {}, toDisplayVars)
);
const viewItems = computed(() => viewContent.value.items || []);
const viewButtonValue = button =>
  button.type === 'web_url' ? button.uri : 'Reply';

const isInvalid = computed(() => errors.value.length > 0);

async function save() {
  showErrors.value = true;
  isSaving.value = true;
  serverErrors.value = [];
  const f = form.value;
  const payload = {
    template: {
      name: f.name.trim(),
      platform: f.platform,
      category: f.category,
      language: f.language,
      content: buildContent(),
    },
  };
  const { ok, data } = editingId.value
    ? await request(
        `/super_admin/default_templates/${editingId.value}`,
        'PUT',
        payload
      )
    : await request('/super_admin/default_templates', 'POST', payload);
  isSaving.value = false;
  if (!ok) {
    serverErrors.value = data.errors || ['Something went wrong'];
    return;
  }
  templates.value = [
    ...templates.value.filter(t => t.id !== data.template.id),
    data.template,
  ].sort((a, b) => a.name.localeCompare(b.name));
  showForm.value = false;
}

const onSaveClick = async () => {
  if (isSaving.value) return;
  if (!isInvalid.value) {
    await save();
    return;
  }
  showErrors.value = true;
  await nextTick();
  document
    .querySelector('[data-error]')
    ?.scrollIntoView({ block: 'center', behavior: 'smooth' });
};

const remove = async template => {
  // eslint-disable-next-line no-alert
  if (!window.confirm(`Delete "${template.name}"?`)) return;
  const { ok } = await request(
    `/super_admin/default_templates/${template.id}`,
    'DELETE'
  );
  if (ok) templates.value = templates.value.filter(t => t.id !== template.id);
};

const inputClass =
  'w-full !m-0 border border-slate-300 rounded-md px-3 py-2 text-sm bg-white';
const buttonClass =
  '!bg-slate-50 !text-slate-600 !border !border-slate-200 hover:!bg-slate-100 disabled:opacity-50 disabled:pointer-events-none px-3 py-2 text-sm rounded-md';
const primaryClass =
  '!bg-woot-500 !text-white px-4 py-2 text-sm rounded-md hover:!bg-woot-600 disabled:opacity-50';
const hintClass = 'text-xs text-slate-500 mt-1 mb-0';
const errorClass = 'text-xs text-red-600 mt-1 mb-0';
const fieldClass = field =>
  (field === 'name' ? nameError.value : fieldError(field))
    ? `${inputClass} !border-red-500`
    : inputClass;
</script>

<template>
  <div>
    <header class="flex px-8 py-4 items-center border-b border-n-weak">
      <div class="flex flex-col flex-grow">
        <h1 class="text-base font-medium text-n-slate-12">Default Templates</h1>
        <p class="text-sm text-slate-500 m-0">
          Template messages that are added to Facebook, Instagram and WhatsApp
          (Twilio) inboxes.
        </p>
      </div>
      <button :class="primaryClass" @click="openCreate">New template</button>
    </header>

    <section class="px-8 py-4">
      <div class="p-4 border border-slate-100 rounded-lg mb-6">
        <h2 class="text-sm font-medium mb-3">Auto sync</h2>
        <div
          v-for="option in SETTING_OPTIONS"
          :key="option.key"
          class="flex items-center gap-6 mb-3 text-sm"
        >
          <span class="flex-grow">{{ option.label }}</span>
          <label class="relative inline-flex items-center cursor-pointer m-0">
            <input
              type="checkbox"
              class="sr-only peer"
              :checked="settings[option.key]"
              @change="updateSetting(option.key, $event.target.checked)"
            />
            <span
              class="w-11 h-6 bg-slate-300 rounded-full peer-checked:bg-woot-500 transition-colors after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white after:rounded-full after:size-5 after:transition-all peer-checked:after:translate-x-5"
            />
          </label>
        </div>
      </div>

      <div class="flex gap-2 border-b border-slate-100 mb-4">
        <button
          v-for="platform in PLATFORMS"
          :key="platform.key"
          class="!bg-transparent !shadow-none px-4 py-2 text-sm -mb-px !rounded-none border-b-2"
          :class="
            activeTab === platform.key
              ? '!border-woot-500 !text-woot-600 font-medium'
              : '!border-transparent !text-slate-600'
          "
          @click="activeTab = platform.key"
        >
          {{ platform.label }} ({{ countFor(platform.key) }})
        </button>
      </div>

      <p v-if="!visibleTemplates.length" class="text-sm text-slate-500">
        No templates yet.
      </p>
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="text-left text-slate-500">
            <th class="py-2">Name</th>
            <th>Type</th>
            <th>Language</th>
            <th />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="template in visibleTemplates"
            :key="template.id"
            class="border-t border-slate-100 cursor-pointer hover:bg-slate-25"
            @click="viewing = template"
          >
            <td class="py-2">{{ template.name }}</td>
            <td>{{ labelFor(CATEGORIES, template.category) }}</td>
            <td>{{ template.language }}</td>
            <td class="text-right">
              <button :class="buttonClass" @click.stop="openEdit(template)">
                Edit
              </button>
              <button
                class="ml-2"
                :class="[buttonClass]"
                @click.stop="remove(template)"
              >
                Delete
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </section>

    <div
      v-if="viewing"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-6"
      @click.self="viewing = null"
    >
      <div
        class="bg-white rounded-lg w-full max-w-2xl max-h-full overflow-y-auto p-6 shadow-2xl border border-slate-200"
      >
        <h2 class="text-base font-medium mb-1">{{ viewing.name }}</h2>
        <p class="text-xs text-slate-500 mt-0 mb-4">
          {{ labelFor(PLATFORMS, viewing.platform) }} ·
          {{ labelFor(CATEGORIES, viewing.category) }} · {{ viewing.language }}
        </p>

        <p
          v-if="viewContent.body"
          class="text-sm whitespace-pre-wrap p-3 bg-slate-50 rounded-md mb-3"
        >
          {{ viewContent.body }}
        </p>

        <div
          v-if="viewing.category === 'quick_reply'"
          class="flex flex-wrap gap-2 mb-3"
        >
          <span
            v-for="(item, idx) in viewItems"
            :key="idx"
            class="text-sm px-3 py-1 border border-slate-200 rounded-full"
          >
            {{ item.title }}
          </span>
        </div>

        <div v-if="viewing.category === 'media'" class="mb-3">
          <img
            v-if="viewContent.media_type === 'image'"
            :src="viewContent.media_url"
            class="max-h-60 rounded-md mb-2"
          />
          <video
            v-else
            :src="viewContent.media_url"
            controls
            class="max-h-60 rounded-md mb-2"
          />
          <p
            v-if="viewContent.caption"
            class="text-sm whitespace-pre-wrap p-3 bg-slate-50 rounded-md m-0"
          >
            {{ viewContent.caption }}
          </p>
        </div>

        <div v-if="viewing.category === 'call_to_action'" class="mb-3">
          <p class="text-sm whitespace-pre-wrap p-3 bg-slate-50 rounded-md">
            {{ viewItems[0]?.text }}
          </p>
          <div
            v-for="(button, idx) in viewItems[0]?.buttons || []"
            :key="idx"
            class="flex justify-between gap-3 text-sm px-3 py-2 border border-slate-200 rounded-md mb-2"
          >
            <span class="font-medium">{{ button.title }}</span>
            <span class="text-slate-500 truncate">
              {{ viewButtonValue(button) }}
            </span>
          </div>
        </div>

        <div v-if="viewing.category === 'card'" class="mb-3">
          <div
            v-for="(card, idx) in viewItems"
            :key="idx"
            class="p-3 border border-slate-200 rounded-md mb-2"
          >
            <img
              v-if="card.media_url"
              :src="card.media_url"
              class="max-h-48 rounded-md mb-2"
            />
            <p class="text-sm font-semibold m-0">{{ card.title }}</p>
            <p
              v-if="card.description"
              class="text-sm text-slate-600 whitespace-pre-wrap mt-1 mb-2"
            >
              {{ card.description }}
            </p>
            <p v-if="card.default_action?.url" :class="hintClass">
              Default action: {{ card.default_action.url }}
            </p>
            <div
              v-for="(button, buttonIdx) in card.actions || []"
              :key="buttonIdx"
              class="flex justify-between gap-3 text-sm px-3 py-2 border border-slate-200 rounded-md mt-2"
            >
              <span class="font-medium">{{ button.title || button.text }}</span>
              <span class="text-slate-500 truncate">
                {{ viewButtonValue(button) }}
              </span>
            </div>
          </div>
        </div>

        <div class="flex justify-end">
          <button :class="buttonClass" @click="viewing = null">Close</button>
        </div>
      </div>
    </div>

    <div
      v-if="showForm"
      class="fixed inset-0 bg-black/50 flex items-start justify-center overflow-y-auto z-50 py-10"
      @click.self="showForm = false"
    >
      <div
        class="bg-white rounded-lg w-full max-w-4xl p-6 shadow-2xl border border-slate-200"
      >
        <h2 class="text-base font-medium mb-4">
          {{ editingId ? 'Edit template' : 'New template' }}
        </h2>

        <div class="grid grid-cols-2 gap-4 mb-4">
          <label class="text-sm">
            Create for
            <select
              v-model="form.platform"
              :class="inputClass"
              :disabled="!!editingId"
              @change="changePlatform"
            >
              <option v-for="p in PLATFORMS" :key="p.key" :value="p.key">
                {{ p.label }}
              </option>
            </select>
            <p :class="hintClass">
              Which inbox type gets this template. Shared templates go to all
              three and follow WhatsApp limits.
            </p>
          </label>
          <label class="text-sm">
            Language
            <input
              v-model="form.language"
              placeholder="en"
              :class="inputClass"
            />
            <p :class="hintClass">{{ HINTS.language }}</p>
          </label>
          <label class="text-sm col-span-2">
            Name
            <input
              v-model="form.name"
              placeholder="order_ready"
              :class="fieldClass('name')"
            />
            <p v-if="nameError" :class="errorClass" data-error>
              {{ nameError }}
            </p>
            <p v-else :class="hintClass">{{ HINTS.name }}</p>
          </label>
        </div>

        <p v-if="isStrict" class="text-xs text-slate-500 mb-3">
          Limits for WhatsApp apply: up to {{ limits.quickReplies }} quick
          replies, {{ limits.buttons }} URL buttons and {{ limits.cards }} card.
        </p>

        <div class="flex flex-wrap gap-2 mb-4">
          <button
            v-for="category in CATEGORIES"
            :key="category.key"
            class="px-3 py-1.5 text-sm rounded-md !border"
            :class="
              form.category === category.key
                ? '!bg-woot-500 !text-white !border-woot-500 ring-2 ring-woot-200'
                : '!bg-slate-50 !text-slate-600 !border-slate-200 hover:!bg-slate-100'
            "
            @click="selectCategory(category.key)"
          >
            {{ category.label }}
          </button>
        </div>

        <div
          v-if="form.category === 'text' || form.category === 'quick_reply'"
          class="mb-4"
        >
          <label class="text-sm">
            Body
            <textarea
              v-model="form.body"
              rows="4"
              :placeholder="VAR_PLACEHOLDER"
              :class="fieldClass('body')"
            />
            <p v-if="fieldError('body')" :class="errorClass" data-error>
              {{ fieldError('body') }}
            </p>
            <p v-else :class="hintClass">{{ HINTS.variables }}</p>
          </label>
        </div>

        <div v-if="form.category === 'quick_reply'" class="mb-4">
          <div
            v-for="(item, idx) in form.items"
            :key="idx"
            class="flex gap-2 mb-3 items-start"
          >
            <div class="flex-1">
              <input
                v-model="item.title"
                placeholder="Yes, confirm"
                :class="inputClass"
              />
              <p :class="hintClass">{{ HINTS.quickReplyTitle }}</p>
            </div>
            <button :class="buttonClass" @click="form.items.splice(idx, 1)">
              ✕
            </button>
          </div>
          <div class="flex items-center gap-3">
            <button
              :class="buttonClass"
              :disabled="form.items.length >= limits.quickReplies"
              @click="form.items.push({ title: '' })"
            >
              Add quick reply
            </button>
            <span :class="hintClass">
              {{ form.items.length }}/{{ limits.quickReplies }}
            </span>
          </div>
        </div>

        <div v-if="form.category === 'media'" class="grid gap-3 mb-4">
          <div>
            <p class="text-sm m-0 mb-1">Image or video</p>
            <p v-if="form.media_url" class="text-sm text-slate-700 m-0 mb-2">
              <img
                v-if="form.media_type === 'image'"
                :src="form.media_url"
                class="h-24 rounded-md border border-slate-200 mb-2"
              />
              <span v-else>Video uploaded</span>
              <button
                class="block"
                :class="[buttonClass]"
                @click="form.media_url = ''"
              >
                Remove
              </button>
            </p>
            <input
              v-else
              type="file"
              :accept="MEDIA_ACCEPT"
              @change="onMediaChange"
            />
            <p v-if="uploading.media" :class="hintClass">Uploading...</p>
            <p v-if="uploadErrors.media" :class="errorClass" data-error>
              {{ uploadErrors.media }}
            </p>
            <p v-else-if="fieldError('media')" :class="errorClass" data-error>
              {{ fieldError('media') }}
            </p>
            <p v-else :class="hintClass">
              Choose a file from your device. It is uploaded to our server and
              the link is stored. Images: PNG/JPEG up to 8 MB. Videos up to 25
              MB.
            </p>
          </div>
          <label class="text-sm">
            Caption
            <textarea
              v-model="form.caption"
              rows="2"
              :placeholder="VAR_PLACEHOLDER"
              :class="inputClass"
            />
            <p :class="hintClass">{{ HINTS.caption }} {{ HINTS.variables }}</p>
          </label>
        </div>

        <div v-if="form.category === 'call_to_action'" class="mb-4">
          <label class="text-sm">
            Text
            <textarea
              v-model="form.ctaText"
              rows="3"
              :placeholder="VAR_PLACEHOLDER"
              :class="fieldClass('body')"
            />
            <p v-if="fieldError('body')" :class="errorClass" data-error>
              {{ fieldError('body') }}
            </p>
            <p v-else :class="hintClass">{{ HINTS.variables }}</p>
          </label>
          <div
            v-for="(button, idx) in form.ctaButtons"
            :key="idx"
            class="flex gap-2 mt-3 items-start"
          >
            <div class="w-32">
              <select v-model="button.type" :class="inputClass">
                <option v-for="type in buttonTypes" :key="type" :value="type">
                  {{ BUTTON_TYPE_LABELS[type] }}
                </option>
              </select>
            </div>
            <div class="flex-1">
              <input
                v-model="button.title"
                :placeholder="buttonPlaceholder(button)"
                :class="inputClass"
              />
              <p :class="hintClass">
                {{
                  button.type === 'postback'
                    ? HINTS.buttonReply
                    : HINTS.buttonTitle
                }}
              </p>
            </div>
            <div v-if="button.type === 'web_url'" class="flex-1">
              <input
                v-model="button.uri"
                placeholder="https://example.com"
                :class="inputClass"
              />
              <p :class="hintClass">{{ HINTS.buttonUrl }}</p>
            </div>
            <button
              :class="buttonClass"
              @click="form.ctaButtons.splice(idx, 1)"
            >
              ✕
            </button>
          </div>
          <div class="flex items-center gap-3 mt-3">
            <button
              :class="buttonClass"
              :disabled="form.ctaButtons.length >= limits.buttons"
              @click="form.ctaButtons.push(emptyButton())"
            >
              Add button
            </button>
            <span :class="hintClass">
              {{ form.ctaButtons.length }}/{{ limits.buttons }}
            </span>
          </div>
        </div>

        <div v-if="form.category === 'card'" class="mb-4">
          <div
            v-for="(card, cardIdx) in form.items"
            :key="cardIdx"
            class="border border-slate-200 rounded-md p-3 mb-3 grid gap-3"
          >
            <label class="text-sm">
              Title
              <input
                v-model="card.title"
                placeholder="Card title"
                :class="inputClass"
              />
              <p :class="hintClass">{{ HINTS.cardTitle }}</p>
            </label>
            <label class="text-sm">
              Description
              <textarea
                v-model="card.description"
                rows="2"
                placeholder="Card description"
                :class="inputClass"
              />
              <p :class="hintClass">{{ HINTS.cardDescription }}</p>
            </label>
            <div>
              <p class="text-sm m-0 mb-1">Image (optional)</p>
              <p v-if="card.media_url" class="m-0 mb-2">
                <img
                  :src="card.media_url"
                  class="h-24 rounded-md border border-slate-200 mb-2"
                />
                <button
                  class="block"
                  :class="[buttonClass]"
                  @click="card.media_url = ''"
                >
                  Remove
                </button>
              </p>
              <input
                v-else
                type="file"
                :accept="IMAGE_ACCEPT"
                @change="onCardMediaChange(cardIdx, $event)"
              />
              <p v-if="uploading[`card-${cardIdx}`]" :class="hintClass">
                Uploading...
              </p>
              <p
                v-if="uploadErrors[`card-${cardIdx}`]"
                :class="errorClass"
                data-error
              >
                {{ uploadErrors[`card-${cardIdx}`] }}
              </p>
              <p v-else :class="hintClass">
                Choose a PNG or JPEG (up to 8 MB) from your device.
              </p>
            </div>
            <label v-if="!isStrict" class="text-sm">
              Default action URL
              <input
                v-model="card.default_action_url"
                placeholder="https://example.com"
                :class="inputClass"
              />
              <p :class="hintClass">{{ HINTS.defaultAction }}</p>
            </label>
            <div
              v-for="(button, idx) in card.actions"
              :key="idx"
              class="flex gap-2 items-start"
            >
              <div class="w-32">
                <select v-model="button.type" :class="inputClass">
                  <option v-for="type in buttonTypes" :key="type" :value="type">
                    {{ BUTTON_TYPE_LABELS[type] }}
                  </option>
                </select>
              </div>
              <div class="flex-1">
                <input
                  v-model="button.title"
                  :placeholder="buttonPlaceholder(button)"
                  :class="inputClass"
                />
                <p :class="hintClass">
                  {{
                    button.type === 'postback'
                      ? HINTS.buttonReply
                      : HINTS.buttonTitle
                  }}
                </p>
              </div>
              <div v-if="button.type === 'web_url'" class="flex-1">
                <input
                  v-model="button.uri"
                  placeholder="https://example.com"
                  :class="inputClass"
                />
                <p :class="hintClass">{{ HINTS.buttonUrl }}</p>
              </div>
              <button :class="buttonClass" @click="card.actions.splice(idx, 1)">
                ✕
              </button>
            </div>
            <div class="flex items-center gap-3">
              <button
                :class="buttonClass"
                :disabled="card.actions.length >= limits.buttons"
                @click="card.actions.push(emptyButton())"
              >
                Add button
              </button>
              <span :class="hintClass">
                {{ card.actions.length }}/{{ limits.buttons }}
              </span>
              <button
                v-if="form.items.length > 1"
                :class="buttonClass"
                @click="form.items.splice(cardIdx, 1)"
              >
                Remove card
              </button>
            </div>
          </div>
          <div class="flex items-center gap-3">
            <button
              :class="buttonClass"
              :disabled="form.items.length >= limits.cards"
              @click="form.items.push(emptyCard())"
            >
              Add card
            </button>
            <span :class="hintClass">
              {{ form.items.length }}/{{ limits.cards }}
            </span>
          </div>
        </div>

        <div
          v-if="generalErrors.length"
          class="mb-3 p-3 border border-red-500 rounded-md"
        >
          <p
            v-for="error in generalErrors"
            :key="error.message"
            :class="errorClass"
            data-error
          >
            {{ error.message }}
          </p>
        </div>
        <div v-if="serverErrors.length" class="mb-3">
          <p
            v-for="error in serverErrors"
            :key="error"
            :class="errorClass"
            data-error
          >
            {{ error }}
          </p>
        </div>

        <div class="flex justify-end gap-2">
          <button :class="buttonClass" @click="showForm = false">Cancel</button>
          <div @click="onSaveClick">
            <button
              :class="[primaryClass, isInvalid && 'pointer-events-none']"
              :disabled="isSaving || isInvalid"
            >
              Save
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
