<script setup>
import { computed } from 'vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import { useMessageContext } from '../provider.js';

const { contentAttributes } = useMessageContext();

const item = computed(() => contentAttributes.value?.items?.[0] ?? {});
const buttons = computed(() => item.value.buttons ?? []);

function onButtonClick(button) {
  if (button.type === 'web_url' && button.uri) {
    window.open(button.uri, '_blank', 'noopener,noreferrer');
  }
}
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="call-to-action">
    <div class="flex flex-col gap-2">
      <p v-if="item.text" class="whitespace-pre-wrap">{{ item.text }}</p>
      <div v-if="buttons.length" class="flex flex-col gap-1.5">
        <button
          v-for="button in buttons"
          :key="button.title"
          type="button"
          class="text-center text-xs font-medium py-1.5 rounded-md bg-white/15"
          :class="
            button.type === 'web_url'
              ? 'cursor-pointer underline'
              : 'cursor-default'
          "
          @click="onButtonClick(button)"
        >
          {{ button.title }}
        </button>
      </div>
    </div>
  </BaseBubble>
</template>
