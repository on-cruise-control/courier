<script setup>
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import twilioConfigurationAPI from 'dashboard/api/twilioConfiguration';
import gotoConfigurationAPI from 'dashboard/api/gotoConfiguration';

import SectionLayout from './SectionLayout.vue';
import TwilioConfiguration from './TwilioConfiguration.vue';
import GotoConfiguration from './GotoConfiguration.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ConfirmationModal from 'dashboard/components/widgets/modal/ConfirmationModal.vue';

const { t } = useI18n();
const route = useRoute();

const provider = ref(route.query.goto_connected ? 'goto' : 'twilio');
const confirmDialogRef = ref(null);

// An account sends its notifications through one provider, so the configured one is replaced when the other is set up.
const isConfigured = async name => {
  if (name === 'goto') {
    const { data } = await gotoConfigurationAPI.get();
    return data.configured;
  }
  const { data } = await twilioConfigurationAPI.get();
  return !!data.id;
};

const selectProvider = async name => {
  if (name === provider.value) return;
  if (await isConfigured(provider.value)) {
    const confirmed = await confirmDialogRef.value.showConfirmation();
    if (!confirmed) return;
  }
  provider.value = name;
};

onMounted(async () => {
  if (!route.query.goto_connected && (await isConfigured('goto'))) {
    provider.value = 'goto';
  }
});
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.SMS_NOTIFICATION_PROVIDER.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.SMS_NOTIFICATION_PROVIDER.NOTE')"
  >
    <p class="text-sm text-n-slate-12">
      {{ t('GENERAL_SETTINGS.FORM.SMS_NOTIFICATION_PROVIDER.CHOOSE') }}
    </p>
    <div class="flex gap-2 mb-3">
      <NextButton
        type="button"
        :solid="provider === 'twilio'"
        :faded="provider !== 'twilio'"
        :blue="provider === 'twilio'"
        :slate="provider !== 'twilio'"
        @click="selectProvider('twilio')"
      >
        {{ t('INBOX_MGMT.ADD.SMS.PROVIDERS.TWILIO') }}
      </NextButton>
      <NextButton
        type="button"
        :solid="provider === 'goto'"
        :faded="provider !== 'goto'"
        :blue="provider === 'goto'"
        :slate="provider !== 'goto'"
        @click="selectProvider('goto')"
      >
        {{ t('INBOX_MGMT.ADD.SMS.PROVIDERS.GOTO') }}
      </NextButton>
    </div>
    <TwilioConfiguration v-if="provider === 'twilio'" />
    <GotoConfiguration v-else />
  </SectionLayout>

  <ConfirmationModal
    ref="confirmDialogRef"
    :title="t('GENERAL_SETTINGS.FORM.SMS_NOTIFICATION_PROVIDER.CONFIRM_TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.SMS_NOTIFICATION_PROVIDER.CONFIRM')"
    :confirm-label="
      t('GENERAL_SETTINGS.FORM.SMS_NOTIFICATION_PROVIDER.CONTINUE')
    "
    :cancel-label="t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.DELETE.CANCEL')"
  />
</template>
