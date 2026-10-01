<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import metaTemplatesApi from 'dashboard/api/metaTemplates';
import { templatePreviewText } from 'dashboard/helper/metaTemplateHelper';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MetaTemplateParser from 'dashboard/components-next/meta/MetaTemplateParser.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  inboxId: { type: Number, default: undefined },
});

const emit = defineEmits(['onSend', 'cancel', 'update:show']);

const { t } = useI18n();

const templates = ref([]);
const isLoading = ref(false);
const selectedTemplate = ref(null);
const query = ref('');

const localShow = computed({
  get: () => props.show,
  set: value => emit('update:show', value),
});

const filteredTemplates = computed(() =>
  templates.value.filter(tpl =>
    tpl.name.toLowerCase().includes(query.value.toLowerCase())
  )
);

async function fetchTemplates() {
  if (!props.inboxId) return;
  isLoading.value = true;
  try {
    const { data } = await metaTemplatesApi.list(props.inboxId);
    templates.value = data.templates || [];
  } finally {
    isLoading.value = false;
  }
}

watch(
  () => props.show,
  visible => {
    if (visible) {
      selectedTemplate.value = null;
      query.value = '';
      fetchTemplates();
    }
  }
);

function selectTemplate(template) {
  selectedTemplate.value = template;
}

function onResetTemplate() {
  selectedTemplate.value = null;
}

function onSendMessage(payload) {
  emit('onSend', payload);
}

function onClose() {
  emit('cancel');
}
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="onClose" size="modal-big">
    <woot-modal-header
      :header-title="t('META_TEMPLATES.MODAL.TITLE')"
      :header-content="
        selectedTemplate
          ? selectedTemplate.name
          : t('META_TEMPLATES.MODAL.SUBTITLE')
      "
    />
    <div class="px-8 py-6">
      <div v-if="!selectedTemplate" class="flex flex-col gap-2">
        <div
          class="flex gap-1 items-center px-2.5 mb-1 rounded-lg bg-n-alpha-black2 outline outline-1 outline-n-weak hover:outline-n-slate-6 dark:hover:outline-n-slate-6 focus-within:outline-n-brand dark:focus-within:outline-n-brand"
        >
          <fluent-icon icon="search" class="text-n-slate-11" size="16" />
          <input
            v-model="query"
            type="search"
            :placeholder="t('META_TEMPLATES.MODAL.SEARCH_PLACEHOLDER')"
            class="reset-base w-full h-9 bg-transparent text-n-slate-12 !text-sm !outline-0"
          />
        </div>

        <div v-if="isLoading" class="text-sm text-n-slate-10 py-4">
          {{ t('META_TEMPLATES.LIST.LOADING') }}
        </div>
        <div
          v-else-if="!filteredTemplates.length"
          class="text-sm text-n-slate-10 py-4"
        >
          {{
            query
              ? t('META_TEMPLATES.MODAL.NO_RESULTS', { query })
              : t('META_TEMPLATES.LIST.EMPTY')
          }}
        </div>
        <div
          v-else
          class="rounded-lg outline outline-1 outline-n-weak max-h-80 overflow-y-auto p-2"
        >
          <template v-for="(tpl, index) in filteredTemplates" :key="tpl.id">
            <button
              type="button"
              class="block w-full text-left p-2.5 rounded-lg hover:bg-n-alpha-2 dark:hover:bg-n-solid-2"
              @click="selectTemplate(tpl)"
            >
              <p class="text-sm font-medium text-n-slate-12">{{ tpl.name }}</p>
              <p
                v-if="templatePreviewText(tpl.content, tpl.category)"
                class="text-xs text-n-slate-10 mt-0.5 line-clamp-2"
              >
                {{ templatePreviewText(tpl.content, tpl.category) }}
              </p>
            </button>
            <hr
              v-if="index !== filteredTemplates.length - 1"
              class="border-b border-solid border-n-slate-6 my-2 mx-auto max-w-[95%]"
            />
          </template>
        </div>
      </div>

      <MetaTemplateParser
        v-else
        :template="selectedTemplate"
        @send-message="onSendMessage"
        @reset-template="onResetTemplate"
      >
        <template #actions="{ sendMessage, resetTemplate, disabled }">
          <footer class="flex gap-2 justify-end mt-2">
            <NextButton
              faded
              slate
              type="reset"
              :label="t('META_TEMPLATES.PARSER.GO_BACK_LABEL')"
              @click="resetTemplate"
            />
            <NextButton
              type="button"
              :label="t('META_TEMPLATES.PARSER.SEND_MESSAGE_LABEL')"
              :disabled="disabled"
              @click="sendMessage"
            />
          </footer>
        </template>
      </MetaTemplateParser>
    </div>
  </woot-modal>
</template>
