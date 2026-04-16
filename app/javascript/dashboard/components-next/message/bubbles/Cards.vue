<script setup>
import { computed } from 'vue';
import MessageMeta from '../MessageMeta.vue';
import { useMessageContext } from '../provider.js';
import { ORIENTATION } from '../constants';

const { contentAttributes, orientation, shouldGroupWithNext } =
  useMessageContext();

const items = computed(() => contentAttributes.value?.items ?? []);

const metaClass = computed(() =>
  orientation.value === ORIENTATION.RIGHT ? 'justify-end' : 'justify-start'
);
</script>

<template>
  <div class="flex flex-col gap-1">
    <div
      class="flex gap-2 overflow-x-auto [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]"
    >
      <div
        v-for="item in items"
        :key="item.title"
        class="w-44 flex-none rounded-lg overflow-hidden bg-white dark:bg-n-solid-3 border border-n-slate-3 dark:border-n-solid-4 shadow-sm"
      >
        <img
          :src="item.media_url"
          :alt="item.title"
          class="w-full h-28 object-cover"
        />
        <div class="p-2">
          <p class="text-xs font-medium text-n-slate-12 leading-snug line-clamp-2">
            {{ item.title }}
          </p>
        </div>
      </div>
    </div>
    <MessageMeta
      v-if="!shouldGroupWithNext"
      class="text-n-slate-11 mt-1"
      :class="metaClass"
    />
  </div>
</template>
