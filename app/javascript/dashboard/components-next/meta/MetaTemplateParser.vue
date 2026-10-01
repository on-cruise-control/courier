<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import {
  collectTemplateTexts,
  extractVariableKeys,
  renderTemplateText,
} from 'dashboard/helper/metaTemplateHelper';

const props = defineProps({
  template: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['sendMessage', 'resetTemplate']);

const { t } = useI18n();

const values = ref({});

const primaryText = computed(() => {
  const content = props.template.content || {};
  if (props.template.category === 'call_to_action') {
    return content.items?.[0]?.text || '';
  }
  return content.body || content.caption || '';
});

const variableKeys = computed(() => {
  const texts = collectTemplateTexts(
    props.template.content,
    props.template.category
  );
  return extractVariableKeys(texts);
});

function renderText(text) {
  return renderTemplateText(text, values.value);
}

const renderedText = computed(() => renderText(primaryText.value));

const isFormInvalid = computed(() =>
  variableKeys.value.some(key => !values.value[key])
);

function resetValues() {
  values.value = Object.fromEntries(variableKeys.value.map(key => [key, '']));
}

watch(() => props.template, resetValues, { immediate: true });

function renderButton(button) {
  return { ...button, title: renderText(button.title) };
}

function buildPayload() {
  const category = props.template.category;
  const content = props.template.content || {};

  if (category === 'quick_reply') {
    return {
      message: renderText(content.body),
      contentType: 'input_select',
      contentAttributes: {
        items: (content.items || []).map(item => ({
          ...item,
          title: renderText(item.title),
        })),
      },
    };
  }
  if (category === 'card') {
    return {
      message: '',
      contentType: 'cards',
      contentAttributes: {
        items: (content.items || []).map(item => ({
          ...item,
          title: renderText(item.title),
          description: renderText(item.description),
          actions: (item.actions || []).map(action => ({
            ...action,
            text: renderText(action.text),
          })),
        })),
      },
    };
  }
  if (category === 'call_to_action') {
    const item = content.items?.[0] || {};
    return {
      message: '',
      contentType: 'call_to_action',
      contentAttributes: {
        items: [
          {
            ...item,
            text: renderText(item.text),
            buttons: (item.buttons || []).map(renderButton),
          },
        ],
      },
    };
  }
  if (category === 'media') {
    return {
      message: renderText(content.caption),
      contentAttributes: {
        remote_media_url: content.media_url,
        remote_media_type: content.media_type,
      },
    };
  }
  return { message: renderText(content.body) };
}

function sendMessage() {
  if (isFormInvalid.value) return;
  emit('sendMessage', buildPayload());
}

function resetTemplate() {
  emit('resetTemplate');
}

defineExpose({ sendMessage, resetTemplate, isFormInvalid });
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-black2">
      <h3 class="text-sm font-medium text-n-slate-12">{{ template.name }}</h3>
      <p class="text-sm whitespace-pre-wrap text-n-slate-12">
        {{ renderedText || t('META_TEMPLATES.PARSER.NO_PREVIEW') }}
      </p>
    </div>

    <div v-if="variableKeys.length">
      <p class="mb-2 text-sm font-semibold">
        {{ t('META_TEMPLATES.PARSER.VARIABLES_LABEL') }}
      </p>
      <div v-for="key in variableKeys" :key="key" class="mb-2">
        <Input
          v-model="values[key]"
          type="text"
          :placeholder="
            t('META_TEMPLATES.PARSER.VARIABLE_PLACEHOLDER', { variable: key })
          "
        />
      </div>
    </div>

    <slot
      name="actions"
      :send-message="sendMessage"
      :reset-template="resetTemplate"
      :disabled="isFormInvalid"
    />
  </div>
</template>
