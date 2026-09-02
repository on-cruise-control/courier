<script setup>
import EmojiOrIcon from 'shared/components/EmojiOrIcon.vue';
import { defineEmits } from 'vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  compact: {
    type: Boolean,
    default: false,
  },
  icon: {
    type: String,
    default: '',
  },
  emoji: {
    type: String,
    default: '',
  },
  isOpen: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['toggle']);

const onToggle = () => {
  emit('toggle');
};
</script>

<template>
  <div
    class="group/accordion flex flex-col w-full rounded-xl bg-white dark:bg-[#1a1919] border border-n-strong shadow-sm transition-all duration-300"
    :class="{ 'ring-1 ring-blue-500/10 border-blue-500/20 shadow-md': isOpen }"
  >
    <button
      class="flex items-center select-none w-full m-0 cursor-pointer justify-between py-4 px-5 transition-all duration-200 hover:bg-black/[0.02] dark:hover:bg-white/[0.02]"
      @click.stop="onToggle"
    >
      <div class="flex items-center gap-3.5">
        <div
          v-if="icon || emoji"
          class="size-8 rounded-xl bg-n-slate-3 dark:bg-white/5 flex items-center justify-center transition-colors"
        >
          <EmojiOrIcon
            class="text-n-slate-11 text-[18px]"
            :icon="icon"
            :emoji="emoji"
          />
        </div>
        <div class="flex flex-col items-start translate-y-[-1px]">
          <h5
            class="text-slate-900 dark:text-slate-100 text-[14px] font-bold leading-none m-0 p-0 text-left rtl:text-right"
          >
            {{ title }}
          </h5>
        </div>
      </div>
      <div class="flex items-center gap-3">
        <slot name="button" />
        <div
          class="flex items-center justify-center size-6 rounded-lg transition-all duration-300"
        >
          <span
            :class="isOpen ? 'i-lucide-minus' : 'i-lucide-plus'"
            class="size-4 text-blue-500 font-bold"
          />
        </div>
      </div>
    </button>

    <div
      v-if="isOpen"
      class="bg-white dark:bg-transparent border-t border-slate-50 rounded-b-xl dark:border-white/5 transition-all duration-300"
      :class="compact ? 'p-0' : 'px-5 py-5'"
    >
      <slot />
    </div>
  </div>
</template>
