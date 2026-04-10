<script setup>
import { computed, ref } from 'vue';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  activeTab: {
    type: String,
    default: wootConstants.ASSIGNEE_TYPE.ME,
  },
});

const emit = defineEmits(['chatTabChange']);

const activeTabIndex = computed(() => {
  return props.items.findIndex(item => item.key === props.activeTab);
});

const onTabChange = key => {
  if (key !== props.activeTab) {
    emit('chatTabChange', key);
  }
};

const keyboardEvents = {
  'Alt+KeyN': {
    action: () => {
      if (props.activeTab === wootConstants.ASSIGNEE_TYPE.ALL) {
        onTabChange(props.items[0].key);
      } else {
        const nextIndex = (activeTabIndex.value + 1) % props.items.length;
        onTabChange(props.items[nextIndex].key);
      }
    },
  },
};

useKeyboardEvents(keyboardEvents);
</script>

<template>
  <div class="flex items-center w-full custom-pill-tabs-v2">
    <!-- Tabs Container -->
    <div
      class="flex-1 flex items-center justify-start gap-0.5 p-0.5 bg-white dark:bg-white/5 rounded-lg select-none transition-all overflow-x-auto flex-nowrap scrollbar-hide"
    >
      <button
        v-for="item in items"
        :key="item.key"
        class="relative flex-1 px-2 py-1 text-[11px] font-bold transition-all duration-300 rounded-md whitespace-nowrap outline-none flex items-center justify-center gap-0.5 flex-shrink-0"
        :class="
          activeTab === item.key
            ? 'bg-n-blue-5 dark:bg-white/10 text-slate-900 dark:text-white shadow-sm'
            : 'text-slate-800 hover:text-slate-900 dark:text-slate-400 dark:hover:text-slate-200'
        "
        @click="onTabChange(item.key)"
      >
        <span>{{ item.name }}</span>
        <span
          v-if="item.count"
          class="font-black text-[10px] bg-slate-200/50 dark:bg-white/10 px-1 rounded-md text-slate-900 dark:text-slate-300"
        >
          {{ item.count }}
        </span>
      </button>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.scrollbar-hide {
  -ms-overflow-style: none;
  scrollbar-width: none;
  &::-webkit-scrollbar {
    display: none;
  }
}
</style>
