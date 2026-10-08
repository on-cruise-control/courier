<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  text: { type: String, required: true },
});
</script>

<template>
  <span
    v-tooltip="{
      content: text,
      placement: 'top',
      popperClass: 'whitespace-pre-line',
    }"
    class="inline-flex align-middle text-n-slate-9 hover:text-n-slate-12"
  >
    <Icon icon="i-lucide-info" class="size-3.5" />
  </span>
</template>
