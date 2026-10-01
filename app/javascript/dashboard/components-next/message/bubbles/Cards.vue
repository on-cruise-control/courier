<script setup>
import { computed, ref } from 'vue';
import MessageMeta from '../MessageMeta.vue';
import Icon from 'next/icon/Icon.vue';
import { useMessageContext } from '../provider.js';
import { ORIENTATION } from '../constants';

const { contentAttributes, orientation, shouldGroupWithNext, attachments } =
  useMessageContext();

const items = computed(() => {
  const rawItems = contentAttributes.value?.items ?? [];
  const attachmentList = attachments?.value ?? [];
  return rawItems.map((item, index) => ({
    ...item,
    resolvedMediaUrl: attachmentList[index]?.dataUrl || item.mediaUrl,
  }));
});

const metaClass = computed(() =>
  orientation.value === ORIENTATION.RIGHT ? 'justify-end' : 'justify-start'
);

const imageErrors = ref({});

function onImageError(index) {
  imageErrors.value = { ...imageErrors.value, [index]: true };
}

function onWheelScroll(e) {
  const el = e.currentTarget;
  if (el.scrollWidth <= el.clientWidth) return;
  if (e.deltaX !== 0) return;
  const atRightEnd = el.scrollLeft + el.clientWidth >= el.scrollWidth;
  const atLeftEnd = el.scrollLeft <= 0;
  if ((e.deltaY > 0 && atRightEnd) || (e.deltaY < 0 && atLeftEnd)) return;
  e.preventDefault();
  el.scrollLeft += e.deltaY;
}
</script>

<template>
  <div class="flex flex-col gap-1 w-full min-w-0">
    <div
      class="flex gap-2 overflow-x-auto [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]"
      @wheel="onWheelScroll"
    >
      <div
        v-for="(item, index) in items"
        :key="index"
        class="w-44 flex-none rounded-lg overflow-hidden bg-white dark:bg-n-solid-3 border border-n-slate-3 dark:border-n-solid-4 shadow-sm"
      >
        <img
          v-if="item.resolvedMediaUrl && !imageErrors[index]"
          :src="item.resolvedMediaUrl"
          :alt="item.title"
          class="w-full h-28 object-cover"
          @error="onImageError(index)"
        />
        <a
          v-else-if="item.mediaUrl"
          :href="item.mediaUrl"
          target="_blank"
          rel="noopener noreferrer"
          class="w-full h-28 flex items-center justify-center bg-n-alpha-1 cursor-pointer"
        >
          <Icon icon="i-lucide-image-off" class="text-n-slate-10 size-6" />
        </a>
        <div class="p-2 flex flex-col gap-1">
          <p
            class="text-xs font-medium text-n-slate-12 leading-snug line-clamp-2"
          >
            {{ item.title }}
          </p>
          <p
            v-if="item.description"
            class="text-xs text-n-slate-11 leading-snug line-clamp-2"
          >
            {{ item.description }}
          </p>
          <div
            v-if="item.actions && item.actions.length"
            class="flex flex-col gap-1.5 mt-1"
          >
            <a
              v-for="(action, actionIndex) in item.actions"
              :key="actionIndex"
              :href="action.uri || item.mediaUrl || undefined"
              target="_blank"
              rel="noopener noreferrer"
              class="text-xs text-n-brand font-medium hover:underline"
            >
              {{ action.text }}
            </a>
          </div>
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
