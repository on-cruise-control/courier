<script setup>
import CustomChannelBadgeIcon from './CustomChannelBadgeIcon.vue';

defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});
</script>

<template>
  <!-- <div class="flex items-center text-n-slate-11 text-xs min-w-0">
    <CustomChannelBadgeIcon
      :inbox="inbox"
      size-class="size-4"
      class="ltr:mr-1 rtl:ml-1 flex-shrink-0"
    />
    <span class="truncate">
      {{ inbox.name }}
    </span>
  </div> -->
</template>
