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

const scrollContainer = ref(null);

const activeTabIndex = computed(() => {
  return props.items.findIndex(item => item.key === props.activeTab);
});

const onTabChange = key => {
  if (key !== props.activeTab) {
    emit('chatTabChange', key);
  }
};

const scroll = direction => {
  if (scrollContainer.value) {
    const scrollAmount = 100;
    scrollContainer.value.scrollBy({
      left: direction === 'left' ? -scrollAmount : scrollAmount,
      behavior: 'smooth',
    });
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
  <div class="flex items-center w-full gap-1.5 custom-pill-tabs-v2">
    <!-- Left Arrow -->
    <button
      class="p-1 text-slate-400 hover:text-slate-600 transition-colors shrink-0"
      @click="scroll('left')"
    >
      <i class="i-lucide-chevron-left h-4 w-4" />
    </button>

    <!-- Tabs Container -->
    <div
      ref="scrollContainer"
      class="flex-1 flex items-center gap-1.5 p-1 bg-white dark:bg-white/5 rounded-xl overflow-x-auto scrollbar-hide select-none transition-all"
    >
      <button
        v-for="item in items"
        :key="item.key"
        class="relative px-2 py-1 text-[13px] font-bold transition-all duration-300 rounded-lg whitespace-nowrap outline-none"
        :class="
          activeTab === item.key
            ? 'bg-n-blue-3 dark:bg-white/10 text-slate-800 dark:text-white shadow-sm'
            : 'text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200'
        "
        @click="onTabChange(item.key)"
      >
        {{ item.name }}
        <span
          v-if="item.count"
          class="ml-1 opacity-70 font-medium text-[11px] bg-slate-100 dark:bg-white/5 p-1 rounded-lg"
        >
          {{ item.count }}
        </span>
      </button>
    </div>

    <!-- Right Arrow -->
    <button
      class="p-1 text-slate-400 hover:text-slate-600 transition-colors shrink-0"
      @click="scroll('right')"
    >
      <i class="i-lucide-chevron-right h-4 w-4" />
    </button>
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
