<script setup>
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BookingEmails from './components/BookingEmails.vue';
import EscalationEmails from './components/EscalationEmails.vue';
import VehiclePartsEmails from './components/VehiclePartsEmails.vue';
import ServiceEmails from './components/ServiceEmails.vue';
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="$t('EMAIL_SETTINGS.TITLE')"
        :description="$t('EMAIL_SETTINGS.DESCRIPTION')"
      />
    </template>
    <template #body>
      <BookingEmails />
      <EscalationEmails />
      <VehiclePartsEmails />
      <ServiceEmails />
    </template>
  </SettingsLayout>
</template>
