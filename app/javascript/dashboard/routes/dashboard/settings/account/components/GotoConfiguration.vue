<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import gotoConfigurationAPI from 'dashboard/api/gotoConfiguration';

import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import GotoConnectButton from 'dashboard/components-next/goto/GotoConnectButton.vue';
import ConfirmationModal from 'dashboard/components/widgets/modal/ConfirmationModal.vue';

const { t } = useI18n();

const isLoading = ref(true);
const isConnecting = ref(false);
const isFetchingLines = ref(false);
const isSaving = ref(false);
const isDeleting = ref(false);
const status = ref({ connected: false, configured: false, phone_number: null });
const lines = ref([]);
const selectedNumber = ref('');
const confirmDialogRef = ref(null);

const isPickingNumber = computed(
  () => status.value.connected && !status.value.configured
);

const loadLines = async () => {
  isFetchingLines.value = true;
  try {
    const { data } = await gotoConfigurationAPI.lines();
    lines.value = data.lines;
  } catch {
    useAlert(t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.API.LINES_ERROR'));
  } finally {
    isFetchingLines.value = false;
  }
};

const loadStatus = async () => {
  try {
    const { data } = await gotoConfigurationAPI.get();
    status.value = data;
    if (isPickingNumber.value) loadLines();
  } catch {
    useAlert(t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.API.ERROR_LOADING'));
  } finally {
    isLoading.value = false;
  }
};

const connect = async () => {
  isConnecting.value = true;
  try {
    const { data } = await gotoConfigurationAPI.authorization();
    window.location.href = data.url;
  } catch (error) {
    isConnecting.value = false;
    useAlert(
      error.response?.data?.error ||
        t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.API.ERROR')
    );
  }
};

const save = async () => {
  isSaving.value = true;
  try {
    const { data } = await gotoConfigurationAPI.update({
      phone_number: selectedNumber.value,
    });
    status.value = { connected: true, ...data };
    useAlert(t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.API.SUCCESS'));
  } catch {
    useAlert(t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.API.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const remove = async () => {
  const confirmed = await confirmDialogRef.value.showConfirmation();
  if (!confirmed) return;

  isDeleting.value = true;
  try {
    await gotoConfigurationAPI.delete();
    status.value = { connected: false, configured: false, phone_number: null };
    lines.value = [];
    selectedNumber.value = '';
    useAlert(t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.DELETE.SUCCESS'));
  } catch {
    useAlert(t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.DELETE.ERROR'));
  } finally {
    isDeleting.value = false;
  }
};

onMounted(loadStatus);
</script>

<template>
  <div>
    <woot-loading-state v-if="isLoading" />
    <div v-else-if="status.configured" class="grid gap-4">
      <WithLabel
        name="goto-phone-number"
        :label="t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.CONNECTED_NUMBER')"
      >
        <NextInput
          :model-value="status.phone_number"
          type="tel"
          class="w-full"
          disabled
        />
      </WithLabel>
      <div>
        <NextButton type="button" ruby :is-loading="isDeleting" @click="remove">
          {{ t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.DELETE.BUTTON') }}
        </NextButton>
      </div>
    </div>
    <form v-else-if="isPickingNumber" class="grid gap-4" @submit.prevent="save">
      <label>
        {{ t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.SELECT_NUMBER') }}
        <select v-model="selectedNumber" required>
          <option value="" disabled>
            {{
              t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.SELECT_PLACEHOLDER')
            }}
          </option>
          <option v-if="isFetchingLines" value="__loading" disabled>
            {{ t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.LOADING_NUMBERS') }}
          </option>
          <option v-for="line in lines" :key="line.number" :value="line.number">
            {{
              line.name === line.number
                ? line.number
                : `${line.name} (${line.number})`
            }}
          </option>
        </select>
      </label>
      <div class="flex gap-2">
        <NextButton
          blue
          type="submit"
          :is-loading="isSaving"
          :disabled="!selectedNumber"
        >
          {{ t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.SUBMIT_BUTTON') }}
        </NextButton>
        <NextButton
          type="button"
          slate
          faded
          :is-loading="isDeleting"
          @click="remove"
        >
          {{ t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.DELETE.CANCEL') }}
        </NextButton>
      </div>
    </form>
    <div v-else>
      <GotoConnectButton :is-loading="isConnecting" @click="connect" />
    </div>
  </div>

  <ConfirmationModal
    ref="confirmDialogRef"
    :title="t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.DELETE.CONFIRM_TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.DELETE.CONFIRM')"
    :confirm-label="t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.DELETE.BUTTON')"
    :cancel-label="t('GENERAL_SETTINGS.FORM.GOTO_CONFIGURATION.DELETE.CANCEL')"
  />
</template>
