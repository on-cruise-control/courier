<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import LoadingState from 'dashboard/components/widgets/LoadingState.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

export default {
  components: {
    LoadingState,
    SettingsFieldSection,
    NextButton,
    SelectInput,
  },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      selectedAgentBotId: null,
      commentAutoReply: this.initialCommentAutoReply(),
      isUpdatingCommentAutoReply: false,
    };
  },
  computed: {
    ...mapGetters({
      agentBots: 'agentBots/getBots',
      uiFlags: 'agentBots/getUIFlags',
    }),
    currentInboxId() {
      return this.inbox?.id || this.$route.params.inboxId;
    },
    activeAgentBot() {
      return this.$store.getters['agentBots/getActiveAgentBot'](
        this.currentInboxId
      );
    },
    supportsCommentAutoReply() {
      return [INBOX_TYPES.FB, INBOX_TYPES.INSTAGRAM].includes(
        this.inbox.channel_type
      );
    },
    isFacebookInbox() {
      return this.inbox.channel_type === INBOX_TYPES.FB;
    },
    commentAutoReplyOptions() {
      if (this.isFacebookInbox) {
        return [
          {
            value: 'disabled',
            label: this.$t('AGENT_BOTS.COMMENT_AUTO_REPLY.DISABLED'),
          },
          {
            value: 'reply',
            label: this.$t('AGENT_BOTS.COMMENT_AUTO_REPLY.COMMENT_REPLY'),
          },
          {
            value: 'reply_and_like',
            label: this.$t(
              'AGENT_BOTS.COMMENT_AUTO_REPLY.COMMENT_REPLY_AND_LIKE'
            ),
          },
        ];
      }
      return [
        {
          value: 'enabled',
          label: this.$t('AGENT_BOTS.COMMENT_AUTO_REPLY.ENABLED'),
        },
        {
          value: 'disabled',
          label: this.$t('AGENT_BOTS.COMMENT_AUTO_REPLY.DISABLED'),
        },
      ];
    },
  },
  watch: {
    activeAgentBot() {
      this.selectedAgentBotId = this.activeAgentBot.id;
    },
  },
  mounted() {
    this.fetchBotData();
  },

  methods: {
    initialCommentAutoReply() {
      if (this.inbox.comment_auto_reply_enabled === false) return 'disabled';
      if (this.inbox.channel_type !== INBOX_TYPES.FB) return 'enabled';
      return this.inbox.comment_like_enabled ? 'reply_and_like' : 'reply';
    },
    fetchBotData() {
      this.$store.dispatch('agentBots/get');
      this.$store.dispatch('agentBots/fetchAgentBotInbox', this.currentInboxId);
    },
    async updateActiveAgentBot() {
      try {
        await this.$store.dispatch('agentBots/setAgentBotInbox', {
          inboxId: this.inbox.id,
          // Added this to make sure that empty values are not sent to the API
          botId: this.selectedAgentBotId ? this.selectedAgentBotId : undefined,
        });
        useAlert(this.$t('AGENT_BOTS.BOT_CONFIGURATION.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('AGENT_BOTS.BOT_CONFIGURATION.ERROR_MESSAGE'));
      }
    },
    async updateCommentAutoReply() {
      this.isUpdatingCommentAutoReply = true;
      try {
        await this.$store.dispatch('inboxes/updateInbox', {
          id: this.inbox.id,
          formData: false,
          comment_auto_reply_enabled: this.commentAutoReply !== 'disabled',
          comment_like_enabled: this.commentAutoReply === 'reply_and_like',
        });
        useAlert(this.$t('AGENT_BOTS.COMMENT_AUTO_REPLY.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('AGENT_BOTS.COMMENT_AUTO_REPLY.ERROR_MESSAGE'));
      } finally {
        this.isUpdatingCommentAutoReply = false;
      }
    },
    async disconnectBot() {
      try {
        await this.$store.dispatch('agentBots/disconnectBot', {
          inboxId: this.inbox.id,
        });
        useAlert(
          this.$t('AGENT_BOTS.BOT_CONFIGURATION.DISCONNECTED_SUCCESS_MESSAGE')
        );
      } catch (error) {
        useAlert(
          error?.message ||
            this.$t('AGENT_BOTS.BOT_CONFIGURATION.DISCONNECTED_ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <div class="mx-6 max-w-4xl">
    <LoadingState v-if="uiFlags.isFetching || uiFlags.isFetchingAgentBot" />
    <form v-else @submit.prevent="updateActiveAgentBot">
      <SettingsFieldSection
        :label="$t('AGENT_BOTS.BOT_CONFIGURATION.TITLE')"
        :help-text="$t('AGENT_BOTS.BOT_CONFIGURATION.DESC')"
        class="[&>div]:!items-start"
      >
        <SelectInput
          v-model="selectedAgentBotId"
          :placeholder="$t('AGENT_BOTS.BOT_CONFIGURATION.SELECT_PLACEHOLDER')"
          :options="agentBots.map(bot => ({ value: bot.id, label: bot.name }))"
        />
        <template #extra>
          <div class="grid grid-cols-1 lg:grid-cols-8 mt-3">
            <div class="col-span-1 lg:col-span-2 invisible" />
            <div class="col-span-1 lg:col-span-6 flex gap-2 mx-1">
              <NextButton
                type="submit"
                :label="$t('AGENT_BOTS.BOT_CONFIGURATION.SUBMIT')"
                :is-loading="uiFlags.isSettingAgentBot"
              />
              <NextButton
                type="button"
                :disabled="!selectedAgentBotId"
                :is-loading="uiFlags.isDisconnecting"
                faded
                ruby
                @click="disconnectBot"
              >
                {{ $t('AGENT_BOTS.BOT_CONFIGURATION.DISCONNECT') }}
              </NextButton>
            </div>
          </div>
        </template>
      </SettingsFieldSection>
    </form>
    <form
      v-if="supportsCommentAutoReply"
      class="mt-6"
      @submit.prevent="updateCommentAutoReply"
    >
      <SettingsFieldSection
        :label="$t('AGENT_BOTS.COMMENT_AUTO_REPLY.TITLE')"
        :help-text="$t('AGENT_BOTS.COMMENT_AUTO_REPLY.DESC')"
        class="[&>div]:!items-start"
      >
        <SelectInput
          v-model="commentAutoReply"
          :options="commentAutoReplyOptions"
        />
        <template #extra>
          <div class="grid grid-cols-1 lg:grid-cols-8 mt-3">
            <div class="col-span-1 lg:col-span-2 invisible" />
            <div class="col-span-1 lg:col-span-6 flex gap-2 mx-1">
              <NextButton
                type="submit"
                :label="$t('AGENT_BOTS.COMMENT_AUTO_REPLY.SUBMIT')"
                :is-loading="isUpdatingCommentAutoReply"
              />
            </div>
          </div>
        </template>
      </SettingsFieldSection>
    </form>
  </div>
</template>
