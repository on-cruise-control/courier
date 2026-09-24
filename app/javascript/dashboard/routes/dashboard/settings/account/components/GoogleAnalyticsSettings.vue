<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';

import SectionLayout from './SectionLayout.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();

const apiSecret = ref('');
const isSubmitting = ref(false);

watch(
  currentAccount,
  () => {
    apiSecret.value = currentAccount.value?.settings?.ga4_api_secret || '';
  },
  { deep: true, immediate: true }
);

const handleSubmit = async () => {
  try {
    isSubmitting.value = true;
    await updateAccount({ ga4_api_secret: apiSecret.value }, { silent: true });
    useAlert(t('GENERAL_SETTINGS.FORM.GOOGLE_ANALYTICS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.GOOGLE_ANALYTICS.API.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.GOOGLE_ANALYTICS.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.GOOGLE_ANALYTICS.NOTE')"
  >
    <form class="grid gap-4" @submit.prevent="handleSubmit">
      <WithLabel
        name="ga4-api-secret"
        :label="t('GENERAL_SETTINGS.FORM.GOOGLE_ANALYTICS.API_SECRET.LABEL')"
      >
        <NextInput
          v-model="apiSecret"
          type="password"
          class="w-full"
          :placeholder="
            t('GENERAL_SETTINGS.FORM.GOOGLE_ANALYTICS.API_SECRET.PLACEHOLDER')
          "
        />
      </WithLabel>

      <div>
        <NextButton blue type="submit" :is-loading="isSubmitting">
          {{ t('GENERAL_SETTINGS.FORM.GOOGLE_ANALYTICS.SUBMIT_BUTTON') }}
        </NextButton>
      </div>
    </form>
  </SectionLayout>
</template>
