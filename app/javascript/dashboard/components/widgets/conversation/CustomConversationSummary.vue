<script setup>
import { ref, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ConversationApi from 'dashboard/api/conversations';
import Spinner from 'shared/components/Spinner.vue';
import MarkdownIt from 'markdown-it';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const md = new MarkdownIt();

const summary = ref('');
const isLoading = ref(false);
const isError = ref(false);
const lastUpdated = ref('');
const lastGeneratedAt = ref(null);

const formatTimestamp = (timestamp) => {
  if (!timestamp) return '';
  const date = new Date(timestamp);
  const options = {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  };
  return date.toLocaleString('en-US', options).replace(',', '');
};

const isRateLimited = () => {
  if (!lastGeneratedAt.value) return false;
  const lastTime = new Date(lastGeneratedAt.value).getTime();
  return (Date.now() - lastTime) < 24 * 60 * 60 * 1000;
};

const fetchSummary = async (forceRefresh = false) => {
  if (!props.conversationId) return;

  const shouldShowLoader = !summary.value || (forceRefresh && !isRateLimited());

  if (shouldShowLoader) {
    isLoading.value = true;
  }
  isError.value = false;
  try {
    const response = await ConversationApi.getSummary(props.conversationId, forceRefresh);
    summary.value = response.data.summary;

    if (response.data.alert_message) {
      useAlert(response.data.alert_message);
    }
    
    if (response.data.last_generated_at) {
      lastGeneratedAt.value = response.data.last_generated_at;
    }

    if (response.data.updated_at) {
      lastUpdated.value = formatTimestamp(response.data.updated_at);
    } else {
      const now = new Date();
      lastUpdated.value = formatTimestamp(now);
    }
  } catch (error) {
    isError.value = true;
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => props.conversationId,
  (newId, oldId) => {
    if (newId !== oldId) {
      summary.value = '';
      lastUpdated.value = '';
    }
    fetchSummary();
  },
  { immediate: true }
);

defineExpose({
  fetchSummary,
});
</script>

<template>
  <div class="p-3 h-full custom-ui-font">
    <div
      v-if="isLoading"
      class="flex flex-col items-center justify-center p-12 h-full bg-n-background rounded-2xl border border-n-weak border-dashed shadow-sm"
    >
      <Spinner />
      <span class="mt-4 text-sm text-n-slate-11 font-medium">
        {{ t('CONVERSATION.SUMMARY.LOADING_MESSAGE') }}
      </span>
    </div>
    <div
      v-else-if="isError"
      class="flex flex-col items-center justify-center h-full p-8 text-center bg-n-background rounded-2xl border border-n-danger-3 shadow-sm mx-1"
    >
      <div class="w-12 h-12 rounded-full bg-n-danger-2 flex items-center justify-center mb-4">
        <i class="i-lucide-alert-circle text-n-danger-11 text-xl" />
      </div>
      <p class="text-n-danger-11 text-sm font-medium mb-4">
        {{ t('CONVERSATION.SUMMARY.ERROR') }}
      </p>
      <button
        class="px-4 py-2 bg-n-brand text-white rounded-full text-xs font-bold hover:opacity-90 transition-all shadow-md active:scale-95"
        @click="fetchSummary"
      >
        {{ t('CONVERSATION.SUMMARY.RETRY') }}
      </button>
    </div>
    <div
      v-else-if="!summary"
      class="flex flex-col items-center justify-center h-full p-8 bg-n-background rounded-2xl border border-n-weak border-dashed mx-1 shadow-sm"
    >
      <div class="w-12 h-12 rounded-full bg-n-alpha-2 flex items-center justify-center mb-4">
        <i class="i-lucide-sparkles text-n-slate-11 text-xl opacity-50" />
      </div>
      <p class="text-n-slate-10 text-sm text-center font-medium max-w-[200px]">
        {{ t('CONVERSATION.SUMMARY.EMPTY') }}
      </p>
    </div>
    <div v-else class="flex flex-col gap-3">
      <!-- Summary Card -->
      <div class="bg-n-background rounded-2xl border border-slate-100 dark:border-white/5 shadow-sm overflow-hidden p-6 relative">
        <div class="flex items-center justify-between mb-4 border-b border-slate-50 dark:border-white/5 pb-3">
           <div class="flex items-center gap-2">
            <i class="i-lucide-sparkles text-n-iris-10 text-sm" />
            <h3 class="text-xs font-bold text-n-slate-12 uppercase tracking-wider">
               AI Summary
            </h3>
           </div>
           <span class="text-[10px] text-n-slate-10 font-medium">
             {{ lastUpdated }}
           </span>
        </div>
        
        <div
          class="prose prose-sm dark:prose-invert max-w-none text-n-slate-11 leading-relaxed text-sm font-normal break-words selection:bg-n-brand selection:text-white"
          v-html="md.render(summary)"
        />
      </div>

      <div class="px-2 flex items-start gap-2 opacity-60">
        <i class="i-lucide-info text-[10px] text-n-slate-9 mt-0.5" />
        <p class="text-[10px] text-n-slate-10 italic leading-tight">
          {{ t('CONVERSATION.SUMMARY.DISCLAIMER') }}
        </p>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.custom-ui-font {
  font-family: 'Outfit', sans-serif !important;
}

::v-deep {
  ul {
    @apply list-disc list-outside ml-4 mt-2 mb-2;
    li {
      @apply mb-1;
    }
  }
  p {
    @apply mb-3 last:mb-0;
  }
}
</style>
