<script>
import PageHeader from '../../SettingsSubPageHeader.vue';
import BandwidthSms from './BandwidthSms.vue';
import Twilio from './Twilio.vue';
import GotoSms from './GotoSms.vue';

export default {
  components: {
    PageHeader,
    Twilio,
    BandwidthSms,
    GotoSms,
  },
  data() {
    const { hash, query } = this.$route;
    const fromUrl = hash.slice(1);
    return {
      provider:
        ['twilio', 'bandwidth', 'goto'].find(name => name === fromUrl) ||
        (query.goto_channel || query.goto_error ? 'goto' : 'twilio'),
    };
  },
  watch: {
    // Keeps the selected provider in the URL (new/sms#goto) so a refresh stays on it.
    provider: {
      immediate: true,
      handler(provider) {
        this.$router.replace({
          query: this.$route.query,
          hash: `#${provider}`,
        });
      },
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.SMS.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.SMS.DESC')"
    />
    <div class="flex-shrink-0 flex-grow-0">
      <label>
        {{ $t('INBOX_MGMT.ADD.SMS.PROVIDERS.LABEL') }}
        <select v-model="provider">
          <option value="twilio">
            {{ $t('INBOX_MGMT.ADD.SMS.PROVIDERS.TWILIO') }}
          </option>
          <option value="bandwidth">
            {{ $t('INBOX_MGMT.ADD.SMS.PROVIDERS.BANDWIDTH') }}
          </option>
          <option value="goto">
            {{ $t('INBOX_MGMT.ADD.SMS.PROVIDERS.GOTO') }}
          </option>
        </select>
      </label>
    </div>
    <Twilio v-if="provider === 'twilio'" type="sms" />
    <GotoSms v-else-if="provider === 'goto'" />
    <BandwidthSms v-else />
  </div>
</template>
