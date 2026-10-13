<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { mapStrings, toDisplayVars } from 'dashboard/helper/metaTemplateHelper';

const props = defineProps({
  show: { type: Boolean, default: false },
  template: { type: Object, default: null },
});

const emit = defineEmits(['update:show']);

const { t } = useI18n();

const content = computed(() =>
  mapStrings(props.template?.content || {}, toDisplayVars)
);
const items = computed(() => content.value.items || []);
const ctaItem = computed(() => items.value[0] || {});

const buttonTitle = button => button.title || button.text;
const buttonValue = button =>
  button.type === 'web_url'
    ? button.uri
    : t('META_TEMPLATES.VIEW.REPLY_BUTTON');

const close = () => emit('update:show', false);
</script>

<template>
  <woot-modal :show="show" :on-close="close" size="medium">
    <woot-modal-header :header-title="template?.name" />
    <div
      v-if="template"
      class="px-4 sm:px-8 pb-8 flex flex-col gap-4 overflow-y-auto max-h-[75vh]"
    >
      <div
        v-if="
          template.category === 'text' || template.category === 'quick_reply'
        "
        class="flex flex-col gap-1"
      >
        <p class="text-xs font-medium text-n-slate-11">
          {{ t('META_TEMPLATES.VIEW.MESSAGE') }}
        </p>
        <p
          class="text-sm text-n-slate-12 whitespace-pre-wrap p-3 bg-n-slate-2 rounded-lg"
        >
          {{ content.body }}
        </p>
      </div>

      <div
        v-if="template.category === 'quick_reply'"
        class="flex flex-col gap-1"
      >
        <p class="text-xs font-medium text-n-slate-11">
          {{ t('META_TEMPLATES.VIEW.QUICK_REPLIES') }}
        </p>
        <div class="flex flex-wrap gap-2">
          <span
            v-for="(item, idx) in items"
            :key="idx"
            class="text-sm px-3 py-1 border border-n-weak rounded-full text-n-slate-12"
          >
            {{ item.title }}
          </span>
        </div>
      </div>

      <div v-if="template.category === 'media'" class="flex flex-col gap-2">
        <img
          v-if="content.media_type === 'image'"
          :src="content.media_url"
          class="max-h-60 rounded-lg object-contain self-start"
        />
        <video
          v-else
          :src="content.media_url"
          controls
          class="max-h-60 rounded-lg self-start"
        />
        <p
          v-if="content.caption"
          class="text-sm text-n-slate-12 whitespace-pre-wrap p-3 bg-n-slate-2 rounded-lg"
        >
          {{ content.caption }}
        </p>
      </div>

      <div
        v-if="template.category === 'call_to_action'"
        class="flex flex-col gap-3"
      >
        <p
          class="text-sm text-n-slate-12 whitespace-pre-wrap p-3 bg-n-slate-2 rounded-lg"
        >
          {{ ctaItem.text }}
        </p>
        <div class="flex flex-col gap-2">
          <p class="text-xs font-medium text-n-slate-11">
            {{ t('META_TEMPLATES.VIEW.BUTTONS') }}
          </p>
          <div
            v-for="(button, idx) in ctaItem.buttons || []"
            :key="idx"
            class="flex items-center justify-between gap-3 text-sm px-3 py-2 border border-n-weak rounded-lg"
          >
            <span class="font-medium text-n-slate-12">
              {{ buttonTitle(button) }}
            </span>
            <span class="text-n-slate-10 truncate">{{
              buttonValue(button)
            }}</span>
          </div>
        </div>
      </div>

      <div v-if="template.category === 'card'" class="flex flex-col gap-3">
        <div
          v-for="(card, idx) in items"
          :key="idx"
          class="flex flex-col gap-2 p-3 border border-n-weak rounded-lg"
        >
          <p class="text-xs font-medium text-n-slate-11">
            {{ t('META_TEMPLATES.VIEW.CARD_NUMBER', { number: idx + 1 }) }}
          </p>
          <img
            v-if="card.media_url"
            :src="card.media_url"
            class="max-h-48 rounded-lg object-contain self-start"
          />
          <p class="text-sm font-semibold text-n-slate-12">{{ card.title }}</p>
          <p
            v-if="card.description"
            class="text-sm text-n-slate-11 whitespace-pre-wrap"
          >
            {{ card.description }}
          </p>
          <p v-if="card.default_action?.url" class="text-xs text-n-slate-10">
            {{ t('META_TEMPLATES.VIEW.DEFAULT_ACTION') }}:
            {{ card.default_action.url }}
          </p>
          <div
            v-for="(action, actionIdx) in card.actions || []"
            :key="actionIdx"
            class="flex items-center justify-between gap-3 text-sm px-3 py-2 border border-n-weak rounded-lg"
          >
            <span class="font-medium text-n-slate-12">
              {{ buttonTitle(action) }}
            </span>
            <span class="text-n-slate-10 truncate">
              {{ buttonValue(action) }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </woot-modal>
</template>
