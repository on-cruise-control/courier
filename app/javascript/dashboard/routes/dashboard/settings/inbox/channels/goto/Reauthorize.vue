<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import InboxReconnectionRequired from '../../components/InboxReconnectionRequired.vue';
import gotoChannel from 'dashboard/api/channel/gotoChannel';

const props = defineProps({
  inbox: { type: Object, required: true },
});

const { t } = useI18n();
const isRequestingAuthorization = ref(false);

async function requestAuthorization() {
  try {
    isRequestingAuthorization.value = true;
    const {
      data: { url },
    } = await gotoChannel.reauthorization(props.inbox.channel_id);
    window.location.href = url;
  } catch (error) {
    useAlert(t('INBOX_MGMT.REAUTHORIZE_ERROR'));
  } finally {
    isRequestingAuthorization.value = false;
  }
}
</script>

<template>
  <InboxReconnectionRequired class="mx-6" @reauthorize="requestAuthorization" />
</template>
