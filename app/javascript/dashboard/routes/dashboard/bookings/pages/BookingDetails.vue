<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();

const bookingId = computed(() => route.params.bookingId);
const booking = ref(null);
const contactThumbnail = computed(() => booking.value?.contact_thumbnail || '');
const isLoading = computed(() => store.getters['bookings/getUIFlags'].isFetching);

const fetchBooking = async () => {
  const recordFromStore = store.getters['bookings/getRecordById'](bookingId.value);
  if (recordFromStore) booking.value = recordFromStore;
  try {
    const data = await store.dispatch('bookings/show', bookingId.value);
    if (data && !data.error) {
      booking.value = data;
    } else if (!booking.value) {
      useAlert(t('BOOKINGS.ERROR_FETCHING'));
    }
  } catch {
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

const formatDate = dateString => {
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
  return statusMap[booking.value?.status?.toLowerCase()] || 'bg-n-slate-3 text-n-slate-11 ring-n-slate-6/20';
});

const goBack = () => router.back();
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <!-- HEADER -->
    <header class="flex-shrink-0 bg-n-surface-1 px-6 py-4">
      <div class="mx-auto max-w-[60rem] flex items-center gap-3">
        <Button
          icon="i-lucide-arrow-left"
          variant="ghost"
          size="sm"
          color="slate"
          @click="goBack"
        />
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('BOOKINGS.DETAILS.HEADER') }}
        </h1>
      </div>
    </header>

    <!-- CONTENT -->
    <main class="flex-1 overflow-y-auto px-6 py-6">
      <div v-if="isLoading" class="flex h-64 items-center justify-center">
        <Spinner />
      </div>

      <div v-else-if="booking" class="mx-auto max-w-[60rem] flex flex-col gap-6">
        <!-- PRIMARY INFO CARD -->
        <section class="flex items-start gap-6 p-6 rounded-2xl bg-n-solid-2 border border-n-weak">
          <Avatar
            :name="booking.name || 'Anonymous'"
            :src="contactThumbnail"
            :size="72"
          />
          <div class="flex-1 min-w-0">
            <h2 class="text-2xl font-bold text-n-slate-12 truncate">
              {{ booking.name || 'Anonymous' }}
            </h2>
            <div class="text-n-brand font-bold uppercase tracking-widest text-xs mt-1">
              {{ booking.type }}
            </div>

            <div class="grid grid-cols-2 gap-6 mt-5 max-sm:grid-cols-1">
              <!-- LEFT -->
              <div class="space-y-4">
                <div>
                  <div class="text-xs font-semibold uppercase tracking-wider text-n-slate-10 mb-1.5">
                    {{ t('BOOKINGS.DETAILS.PHONE') }}
                  </div>
                  <div v-if="booking.phone || booking.whatsapp_number || booking.sms_number" class="space-y-1">
                    <div v-if="booking.phone" class="flex items-center gap-2 text-sm text-n-slate-12">
                      <span class="i-lucide-phone size-4 text-n-slate-9 flex-shrink-0" />
                      <span class="truncate">{{ booking.phone }}</span>
                    </div>
                    <div v-if="booking.whatsapp_number" class="flex items-center gap-2 text-sm text-n-slate-12">
                      <span class="i-ph-whatsapp-logo size-4 text-n-slate-9 flex-shrink-0" />
                      <span class="truncate">{{ booking.whatsapp_number }}</span>
                    </div>
                    <div v-if="booking.sms_number" class="flex items-center gap-2 text-sm text-n-slate-12">
                      <span class="i-lucide-message-square size-4 text-n-slate-9 flex-shrink-0" />
                      <span class="truncate">{{ booking.sms_number }}</span>
                    </div>
                  </div>
                  <div v-else class="text-sm text-n-slate-10">
                    {{ t('BOOKINGS.DETAILS.NOT_AVAILABLE') }}
                  </div>
                </div>

                <div>
                  <div class="text-xs font-semibold uppercase tracking-wider text-n-slate-10 mb-1.5">
                    {{ t('BOOKINGS.DETAILS.STATUS') }}
                  </div>
                  <span
                    class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold ring-1 ring-inset capitalize"
                    :class="statusBadgeClass"
                  >
                    {{ booking.status || '-' }}
                  </span>
                </div>
              </div>

              <!-- RIGHT -->
              <div class="space-y-4">
                <div>
                  <div class="text-xs font-semibold uppercase tracking-wider text-n-slate-10 mb-1.5">
                    {{ t('BOOKINGS.DETAILS.EMAIL') }}
                  </div>
                  <div v-if="booking.email" class="flex items-center gap-2 text-sm text-n-slate-12">
                    <span class="i-lucide-mail size-4 text-n-slate-9 flex-shrink-0" />
                    <span class="truncate">{{ booking.email }}</span>
                  </div>
                  <div v-else class="text-sm text-n-slate-10">
                    {{ t('BOOKINGS.DETAILS.NOT_AVAILABLE') }}
                  </div>
                </div>

                <div>
                  <div class="text-xs font-semibold uppercase tracking-wider text-n-slate-10 mb-1.5">
                    {{ t('BOOKINGS.DETAILS.PLATFORM') }}
                  </div>
                  <div class="flex items-center gap-2 text-sm text-n-slate-12 capitalize">
                    <span :class="platformIcon" class="size-4 text-n-slate-9 flex-shrink-0" />
                    <span>{{ booking.platform || t('BOOKINGS.DETAILS.NOT_AVAILABLE') }}</span>
                  </div>
                </div>

                <div v-if="booking.created_at">
                  <div class="text-xs font-semibold uppercase tracking-wider text-n-slate-10 mb-1.5">
                    {{ t('BOOKINGS.DETAILS.DATE') }}
                  </div>
                  <div class="text-sm text-n-slate-12">
                    {{ formatDate(booking.created_at) }}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <!-- SUMMARY CARD -->
        <section>
          <h3 class="text-base font-semibold text-n-slate-12 mb-3">
            {{ t('BOOKINGS.DETAILS.SUMMARY') }}
          </h3>
          <div class="p-5 rounded-2xl bg-n-solid-2 border border-n-weak min-h-[8rem] text-sm text-n-slate-11 leading-relaxed">
            <p class="whitespace-pre-wrap">{{ booking.latest_summary || booking.summary || t('BOOKINGS.DETAILS.NO_SUMMARY') }}</p>
          </div>
        </section>
      </div>
    </main>
  </div>
</template>
