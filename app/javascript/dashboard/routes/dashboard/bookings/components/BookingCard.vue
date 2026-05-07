<script setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  booking: { type: Object, required: true },
});

const router = useRouter();

const name = computed(() => props.booking.name || 'Anonymous');
const email = computed(() => props.booking.email);
const phone = computed(() => props.booking.phone);
const contactThumbnail = computed(() => props.booking.contact_thumbnail || '');
const summary = computed(() => props.booking.summary);
const status = computed(() => props.booking.status);
const createdAt = computed(() => props.booking.created_at);
const platform = computed(() => props.booking.platform);

const formatDate = (dateString) => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return new Intl.DateTimeFormat('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
};

const statusBadgeClass = computed(() => {
  const statusMap = {
    completed: 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400',
    pending: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400',
    cancelled: 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400',
    in_progress: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400',
  };
  return statusMap[status.value?.toLowerCase()] || 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400';
});

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

const onClickViewDetails = () => {
  router.push({
    name: 'bookings_details',
    params: { bookingId: props.booking.id },
  });
};
</script>

<template>
  <CardLayout layout="row" class="hover:bg-n-solid-3 transition-colors duration-200">
    <div class="flex items-center justify-start flex-1 gap-4">
      <Avatar
        :name="name"
        :src="contactThumbnail"
        :size="48"
        rounded-full
      />
      <div class="flex flex-col gap-0.5 flex-1 min-w-0">
        <div class="flex flex-wrap items-center gap-x-4 gap-y-1">
          <span class="text-base font-medium truncate text-n-slate-12">
            {{ name }}
          </span>
          <div class="flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium" :class="statusBadgeClass">
            {{ status }}
          </div>
        </div>
        
        <div class="flex flex-wrap items-center justify-start gap-x-3 gap-y-1 mt-1">
          <div v-if="email" class="flex items-center gap-1.5 text-sm text-n-slate-11 min-w-0">
            <span class="i-lucide-mail size-3.5 flex-shrink-0" />
            <span class="truncate" :title="email">{{ email }}</span>
          </div>
          <div v-if="email && phone" class="w-px h-3 bg-n-slate-6 flex-shrink-0" />
          <div v-if="phone" class="flex items-center gap-1.5 text-sm text-n-slate-11 flex-shrink-0">
            <span class="i-lucide-phone size-3.5" />
            <span>{{ phone }}</span>
          </div>
          <div v-if="platform" class="w-px h-3 bg-n-slate-6 flex-shrink-0" />
          <div v-if="platform" class="flex items-center gap-1.5 text-sm text-n-slate-11 flex-shrink-0">
            <span :class="platformIcon" class="size-3.5" />
            <span>{{ platform || 'Not Available' }}</span>
          </div>
        </div>

        <div v-if="summary" class="mt-2 p-2.5 bg-n-alpha-2 rounded-lg border border-n-weak/50">
          <p class="text-xs text-n-slate-11 line-clamp-2 leading-relaxed">
            {{ summary }}
          </p>
        </div>
      </div>
    </div>
    
    <div class="flex flex-col items-end justify-between self-stretch pl-4">
      <div class="flex flex-col items-end gap-1">
        <span class="text-xs text-n-slate-10 whitespace-nowrap pt-1">
          {{ formatDate(createdAt) }}
        </span>
        <div class="text-[10px] uppercase tracking-wider font-bold text-n-brand">
          {{ booking.type }}
        </div>
      </div>
      <Button
        label="View Details"
        variant="link"
        size="xs"
        icon="i-lucide-arrow-right"
        trailing-icon
        @click="onClickViewDetails"
      />
    </div>
  </CardLayout>
</template>
