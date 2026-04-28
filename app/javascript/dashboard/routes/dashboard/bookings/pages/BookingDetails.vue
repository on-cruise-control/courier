<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import ConversationAPI from 'dashboard/api/inbox/conversation';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();

const bookingId = computed(() => route.params.bookingId);
const booking = ref(null);
const contactThumbnail = ref('');
const isLoading = computed(() => store.getters['bookings/getUIFlags'].isFetching);

const fetchContactThumbnail = async (conversationId) => {
  if (!conversationId) return;
  try {
    const { data } = await ConversationAPI.show(conversationId);
    const thumbnail = data?.meta?.sender?.thumbnail;
    if (thumbnail) contactThumbnail.value = thumbnail;
  } catch {
    // silently ignore — avatar is non-critical
  }
};

const fetchBooking = async () => {
  // Try to find in store first for instant load
  const recordFromStore = store.getters['bookings/getRecordById'](bookingId.value);
  if (recordFromStore) {
    booking.value = recordFromStore;
    fetchContactThumbnail(recordFromStore.conversation_id);
  }

  try {
    const data = await store.dispatch('bookings/show', bookingId.value);
    // Only update if it's not an error object
    if (data && !data.error) {
      booking.value = data;
      fetchContactThumbnail(data.conversation_id);
    } else if (!booking.value) {
      // If we don't have it in store AND API failed, alert
      useAlert(t('BOOKINGS.ERROR_FETCHING'));
    }
  } catch (error) {
    if (!booking.value) {
      useAlert(t('BOOKINGS.ERROR_FETCHING'));
    }
  }
};

onMounted(fetchBooking);

const platform = computed(() => booking.value?.platform);

const platformIcon = computed(() => {
  const iconMap = {
    sms: 'i-lucide-message-square',
    whatsapp: 'i-ph-whatsapp-logo',
    instagram: 'i-lucide-instagram',
    facebook: 'i-lucide-facebook',
    telegram: 'i-ph-telegram-logo',
    email: 'i-lucide-mail',
    website: 'i-lucide-globe',
    admin: 'i-lucide-globe',
  };
  return iconMap[platform.value?.toLowerCase()] || 'i-lucide-help-circle';
});

const formatDate = (dateString) => {
  if (!dateString) return '-';
  return new Intl.DateTimeFormat('en-US', {
    dateStyle: 'long',
    timeStyle: 'medium',
  }).format(new Date(dateString));
};

const statusBadgeClass = computed(() => {
  const statusMap = {
    completed: 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400 ring-green-600/20',
    pending: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400 ring-yellow-600/20',
    cancelled: 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400 ring-red-600/20',
    in_progress: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400 ring-blue-600/20',
  };
  return statusMap[booking.value?.status?.toLowerCase()] || 'bg-slate-100 text-slate-800 dark:bg-slate-900/30 dark:text-slate-400 ring-slate-600/20';
});

const goBack = () => {
  router.back();
};
</script>

<template>
  <div class="flex flex-col flex-1 h-full m-0 overflow-auto bg-n-background">
    <div class="mx-auto max-w-[60rem] w-full flex flex-col h-full">
      <!-- HEADER -->
      <header class="flex items-center gap-4 pt-8 pb-6 bg-n-background sticky top-0 z-20">
        <Button
          icon="i-lucide-arrow-left"
          variant="ghost"
          size="sm"
          color="slate"
          @click="goBack"
        />
        <h1 class="text-2xl font-semibold text-n-slate-12">
          {{ t('BOOKINGS.HEADER') }} Details
        </h1>
      </header>

      <main class="flex-1 pb-10">
        <div v-if="isLoading" class="flex h-64 items-center justify-center">
          <Spinner />
        </div>

        <div v-else-if="booking" class="flex flex-col gap-8">
          <!-- PRIMARY INFO -->
          <section class="p-8 rounded-2xl bg-n-solid-2 border border-n-weak/50 shadow-sm flex items-start gap-8">
            <Avatar
              :name="booking.name || 'Anonymous'"
              :src="contactThumbnail"
              :size="80"
              rounded-full
            />
            <div class="flex-1 space-y-4">
              <div>
                <h2 class="text-3xl font-bold text-n-slate-12">{{ booking.name || 'Anonymous' }}</h2>
                <div class="text-n-brand font-bold uppercase tracking-widest text-xs mt-1">{{ booking.type }}</div>
              </div>
              
              <div class="grid grid-cols-2 gap-y-6 gap-x-12">
                <!-- LEFT COLUMN -->
                <div class="space-y-6">
                  <!-- Phone / Messaging -->
                  <div class="space-y-1">
                    <div class="text-xs font-bold uppercase text-n-slate-10 tracking-wider">Phone / Messaging</div>
                    <div class="space-y-1.5 mt-1">
                      <div v-if="booking.phone" class="text-sm font-medium text-n-slate-12 flex items-center gap-2">
                        <span class="i-lucide-phone size-4 text-n-slate-9" />
                        {{ booking.phone }}
                      </div>
                      <div v-if="booking.whatsapp_number" class="text-sm font-medium text-n-slate-12 flex items-center gap-2">
                        <span class="i-ph-whatsapp-logo size-4 text-n-slate-9" />
                        {{ booking.whatsapp_number }}
                      </div>
                      <div v-if="booking.sms_number" class="text-sm font-medium text-n-slate-12 flex items-center gap-2">
                        <span class="i-lucide-message-square size-4 text-n-slate-9" />
                        {{ booking.sms_number }}
                      </div>
                      <div v-if="!booking.phone && !booking.whatsapp_number && !booking.sms_number" class="text-sm text-n-slate-10">
                        Not Available
                      </div>
                    </div>
                  </div>

                  <!-- Status -->
                  <div class="space-y-1">
                    <div class="text-xs font-bold uppercase text-n-slate-10 tracking-wider">Status</div>
                    <div class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold ring-1 ring-inset capitalize" :class="statusBadgeClass">
                      {{ booking.status || 'No Status' }}
                    </div>
                  </div>
                </div>

                <!-- RIGHT COLUMN -->
                <div class="space-y-6">
                  <!-- Email -->
                  <div class="space-y-1">
                    <div class="text-xs font-bold uppercase text-n-slate-10 tracking-wider">Email</div>
                    <div v-if="booking.email" class="text-sm font-medium text-n-slate-12 flex items-center gap-2">
                      <span class="i-lucide-mail size-4 text-n-slate-9" />
                      {{ booking.email }}
                    </div>
                    <div v-else class="text-sm text-n-slate-10 flex items-center gap-2">
                      <span class="i-lucide-mail size-4 text-n-slate-8" />
                      Not Available
                    </div>
                  </div>

                  <!-- Platform -->
                  <div class="space-y-1">
                    <div class="text-xs font-bold uppercase text-n-slate-10 tracking-wider">Platform</div>
                    <div class="text-sm font-medium text-n-slate-12 flex items-center gap-2 capitalize">
                      <span :class="platformIcon" class="size-4 text-n-slate-9" />
                      {{ booking.platform || 'Not Available' }}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <!-- SUMMARY SECTION -->
          <section class="space-y-4">
            <h3 class="text-lg font-bold text-n-slate-12">Interaction Summary</h3>
            <div class="p-6 rounded-2xl bg-n-solid-2 border border-n-weak/50 min-h-[12rem] text-n-slate-11 leading-relaxed shadow-sm">
              <p class="whitespace-pre-wrap">{{ booking.latest_summary || booking.summary || 'No summary available for this booking.' }}</p>
            </div>
          </section>
        </div>
      </main>
    </div>
  </div>
</template>
