<script setup>
import Button from './button/Button.vue';
defineProps({
  title: {
    type: String,
    required: true,
  },
  buttons: {
    type: Array,
    default: () => [],
  },
  closeIcon: {
    type: String,
    default: 'i-lucide-x',
  },
});

defineEmits(['click', 'close']);
</script>

<template>
  <div class="border-b border-n-weak bg-white dark:bg-n-background">
    <div class="flex items-center justify-between px-4 py-2 h-12">
      <div class="flex items-center justify-between gap-2 flex-1">
        <span class="text-[11px] font-black uppercase tracking-[0.2em] text-slate-800 dark:text-slate-100">{{ title }}</span>
        <div class="flex items-center">
          <Button
            v-tooltip="$t('GENERAL.CLOSE')"
            :icon="closeIcon"
            ghost
            sm
            class="!text-blue-500 hover:bg-transparent"
            @click="$emit('close')"
          />
        </div>
      </div>
    </div>
  </div>
</template>
