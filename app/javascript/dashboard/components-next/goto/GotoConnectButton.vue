<script setup>
import { useI18n } from 'vue-i18n';

defineProps({ isLoading: { type: Boolean, default: false } });
defineEmits(['click']);

const { t } = useI18n();
</script>

<template>
  <button
    type="button"
    class="flex gap-2 items-center px-4 h-10 text-sm font-semibold bg-[#111827] dark:bg-white rounded-md shadow-md outline outline-1 outline-n-weak disabled:opacity-50"
    :disabled="isLoading"
    @click="$emit('click')"
  >
    <img
      class="w-auto h-5 dark:hidden"
      src="~dashboard/assets/images/channels/goto_logo_dark.png"
      alt="GoTo-logo"
    />
    <img
      class="hidden w-auto h-5 dark:block"
      src="~dashboard/assets/images/channels/goto_logo.png"
      alt="GoTo-logo"
    />
    <span class="text-white dark:text-[#000]">
      {{ t('INBOX_MGMT.ADD.SMS.GOTO.CONNECT_BUTTON') }}
    </span>
  </button>
</template>
