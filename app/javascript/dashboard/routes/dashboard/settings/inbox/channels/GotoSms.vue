<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import GotoChannel from 'dashboard/api/channel/gotoChannel';
import InboxesAPI from 'dashboard/api/inboxes';
import NextButton from 'dashboard/components-next/button/Button.vue';
import GotoConnectButton from 'dashboard/components-next/goto/GotoConnectButton.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const channelId = computed(() => route.query.goto_channel);
const errorMessages = computed(() => ({
  CREATE_ERROR: t('INBOX_MGMT.ADD.SMS.GOTO.API.CREATE_ERROR'),
  LINES_ERROR: t('INBOX_MGMT.ADD.SMS.GOTO.API.LINES_ERROR'),
}));
const errorMessage = computed(
  () => errorMessages.value[route.query.goto_error]
);
const lines = ref([]);
const selectedNumber = ref('');
const inboxName = ref('');
const isLoading = ref(false);
const isFetchingLines = ref(false);
const formError = ref('');
// A native <option> can only hold text, so the loader is animated dots after the text.
const dots = ref(0);
const dotsTimer = setInterval(() => {
  dots.value = (dots.value + 1) % 4;
}, 400);
onUnmounted(() => clearInterval(dotsTimer));

const connect = async () => {
  isLoading.value = true;
  try {
    const { data } = await GotoChannel.authorization();
    window.location.href = data.url;
  } catch (error) {
    isLoading.value = false;
    useAlert(
      error.response?.data?.error || t('INBOX_MGMT.ADD.SMS.GOTO.API.ERROR')
    );
  }
};

// Any failure after connecting sends the user back to a fresh GoTo connect screen, which shows the error above the button.
const restart = error => {
  router.replace({
    name: 'settings_inboxes_page_channel',
    params: { sub_page: 'sms' },
    query: { goto_error: error },
    hash: '#goto',
  });
};

const createInbox = async () => {
  isLoading.value = true;
  formError.value = '';
  try {
    const { data } = await GotoChannel.createInbox(channelId.value, {
      name: inboxName.value.trim(),
      phone_number: selectedNumber.value,
    });
    InboxesAPI.syncServiceHours(data.id)
      .then(() => useAlert(t('INBOX_MGMT.SERVICE_HOURS.SYNC_SUCCESS')))
      .catch(() => useAlert(t('INBOX_MGMT.SERVICE_HOURS.SYNC_ERROR')));
    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: data.id },
    });
  } catch (error) {
    const formErrors = {
      phone_number_taken: t('INBOX_MGMT.ADD.SMS.GOTO.API.NUMBER_TAKEN'),
      name_taken: t('INBOX_MGMT.ADD.SMS.GOTO.API.NAME_TAKEN'),
    };
    const message = formErrors[error.response?.data?.error];
    if (message) {
      isLoading.value = false;
      formError.value = message;
      return;
    }
    restart('CREATE_ERROR');
  }
};

onMounted(async () => {
  if (!channelId.value) return;
  isFetchingLines.value = true;
  try {
    const { data } = await GotoChannel.lines(channelId.value);
    lines.value = data.lines;
  } catch {
    restart('LINES_ERROR');
  } finally {
    isFetchingLines.value = false;
  }
});
</script>

<template>
  <div class="flex flex-col gap-4 mt-4">
    <div
      v-if="!channelId"
      class="flex flex-col items-center justify-center py-12 text-center"
    >
      <p v-if="errorMessage" class="pb-4 text-sm text-n-ruby-11">
        {{ errorMessage }}
      </p>
      <GotoConnectButton :is-loading="isLoading" @click="connect" />
      <p class="py-6 text-sm text-n-slate-11">
        {{ t('INBOX_MGMT.ADD.SMS.GOTO.HELP') }}
      </p>
    </div>
    <form
      v-else
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createInbox"
    >
      <label>
        {{ t('INBOX_MGMT.ADD.SMS.GOTO.INBOX_NAME.LABEL') }}
        <input
          v-model="inboxName"
          type="text"
          required
          :placeholder="t('INBOX_MGMT.ADD.SMS.GOTO.INBOX_NAME.PLACEHOLDER')"
        />
      </label>
      <label>
        {{ t('INBOX_MGMT.ADD.SMS.GOTO.SELECT_NUMBER') }}
        <select v-model="selectedNumber" required>
          <option value="" disabled>
            {{ t('INBOX_MGMT.ADD.SMS.GOTO.SELECT_NUMBER_PLACEHOLDER') }}
          </option>
          <option v-if="isFetchingLines" value="__loading" disabled>
            {{ t('INBOX_MGMT.ADD.SMS.GOTO.LOADING_NUMBERS')
            }}{{ '.'.repeat(dots) }}
          </option>
          <option v-else-if="!lines.length" value="__none" disabled>
            {{ t('INBOX_MGMT.ADD.SMS.GOTO.NO_NUMBERS') }}
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
      <p v-if="formError" class="text-sm text-n-ruby-11">
        {{ formError }}
      </p>
      <div class="w-full mt-4">
        <NextButton
          :is-loading="isLoading"
          type="submit"
          solid
          blue
          :disabled="!selectedNumber"
          :label="t('INBOX_MGMT.ADD.SMS.GOTO.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
