<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { DotLottieVue } from '@lottiefiles/dotlottie-vue';
import travelLottieData from 'dashboard/assets/lottie/travel-app.json';
import FeaturePlaceholder from './FeaturePlaceholder.vue';

defineProps({
  message: {
    type: String,
    required: true,
  },
});

const { accountId } = useAccount();
const isFeatureEnabledonAccount = useMapGetter('accounts/isFeatureEnabledonAccount');

const isCustomUIEnabled = computed(() => {
  if (!accountId.value) return false;
  return isFeatureEnabledonAccount.value(accountId.value, FEATURE_FLAGS.CUSTOM_UI);
});
</script>

<template>
  <div class="relative flex flex-col items-center justify-center h-full w-full overflow-hidden">
    
    <!-- Custom UI -->
    <div v-if="isCustomUIEnabled" class="absolute inset-0 flex items-center justify-center pointer-events-none select-none z-0">
       <div class="absolute w-[500px] h-[500px] bg-blue-300/20 dark:bg-blue-600/10 rounded-full blur-3xl -translate-y-12"></div>
       <div class="absolute w-[400px] h-[400px] bg-teal-200/20 dark:bg-teal-600/10 rounded-full blur-3xl translate-y-24 translate-x-24"></div>
    </div>

    <!-- Custom Premium UI Layout -->
    <div v-if="isCustomUIEnabled" class="relative z-10 flex flex-col items-center justify-center w-full max-w-3xl transform transition-all p-6">
      
      <!-- Animated Graphic Top -->
      <div class="relative flex items-center justify-center mb-6">
        <div class="absolute inset-0 bg-white/10 dark:bg-black/20 blur-2xl rounded-full scale-75"></div>
        <DotLottieVue
          class="relative z-10"
          style="height: 320px; width: 320px; filter: drop-shadow(0 20px 25px rgba(0,0,0,0.06));"
          autoplay
          loop
          :data="travelLottieData"
        />
      </div>

      <!-- Text Content -->
      <h2 class="text-[1.30rem] text-slate-800 dark:text-slate-100 tracking-tight leading-tight mb-4 text-center">
        {{ message }}
      </h2>

      <!-- Commands inside a Glassmorphic Pill -->
      <div class="flex flex-col items-center bg-white/60 dark:bg-[#111112] backdrop-blur-xl px-12 py-6">
        <FeaturePlaceholder class="!mt-0" />
      </div>
    </div>

    <!--Standard Default UI -->
    <template v-else>
      <img
        class="m-4 w-32 hidden dark:block"
        src="dashboard/assets/images/no-chat-dark.svg"
        alt="No Chat dark"
      />
      <img
        class="m-4 w-32 block dark:hidden"
        src="dashboard/assets/images/no-chat.svg"
        alt="No Chat"
      />
      <span class="text-sm text-n-slate-12 font-medium text-center">
        {{ message }}
        <br />
      </span>
      <!-- Cmd bar, keyboard shortcuts placeholder -->
      <FeaturePlaceholder />
    </template>
  </div>
</template>
