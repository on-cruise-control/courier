<script setup>
import { useI18n } from 'vue-i18n';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';
import BookingEmails from './components/BookingEmails.vue';
import EscalationEmails from './components/EscalationEmails.vue';
import VehiclePartsEmails from './components/VehiclePartsEmails.vue';
import ServiceEmails from './components/ServiceEmails.vue';
import SalesEscalationEmails from './components/SalesEscalationEmails.vue';
import ServiceEscalationEmails from './components/ServiceEscalationEmails.vue';
import VehiclePartsEscalationEmails from './components/VehiclePartsEscalationEmails.vue';

const { t } = useI18n();

// Notification sections grouped into independently collapsible category cards.
// To add another notification type later, build its `*Emails.vue` section
// component and drop it into the relevant group's `sections`.
const notificationGroups = [
  {
    key: 'BOOKING',
    title: t('EMAIL_SETTINGS.GROUPS.BOOKING'),
    sections: [BookingEmails, VehiclePartsEmails],
  },
  {
    key: 'SERVICE',
    title: t('EMAIL_SETTINGS.GROUPS.SERVICE'),
    sections: [ServiceEmails],
  },
  {
    key: 'ESCALATION',
    title: t('EMAIL_SETTINGS.GROUPS.ESCALATION'),
    sections: [
      EscalationEmails,
      SalesEscalationEmails,
      ServiceEscalationEmails,
      VehiclePartsEscalationEmails,
    ],
  },
];
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
      <div class="flex flex-col gap-4">
        <Accordion
          v-for="group in notificationGroups"
          :key="group.key"
          :title="group.title"
          is-open
        >
          <component
            :is="section"
            v-for="(section, index) in group.sections"
            :key="index"
          />
        </Accordion>
      </div>
    </template>
  </SettingsLayout>
</template>
