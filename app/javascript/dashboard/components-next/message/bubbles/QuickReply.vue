<script setup>
import { computed } from 'vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import { useMessageContext } from '../provider.js';

const { content, contentAttributes } = useMessageContext();

const items = computed(() =>
  (contentAttributes.value?.items ?? []).filter(item => item.title)
);
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="quick-reply">
    <div class="flex flex-col gap-2">
      <p v-if="content" class="whitespace-pre-wrap">{{ content }}</p>
      <div v-if="items.length" class="flex flex-col gap-1.5">
        <div
          v-for="(item, index) in items"
          :key="index"
          class="text-center text-xs font-medium py-1.5 rounded-md bg-white/15"
        >
          {{ item.title }}
        </div>
      </div>
    </div>
  </BaseBubble>
</template>
