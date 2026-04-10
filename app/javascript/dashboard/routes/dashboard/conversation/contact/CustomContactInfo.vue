<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useAdmin } from 'dashboard/composables/useAdmin';
import ContactInfoRow from './ContactInfoRow.vue';
import Avatar from 'next/avatar/Avatar.vue';
import SocialIcons from './SocialIcons.vue';
import EditContact from './EditContact.vue';
import ContactMergeModal from 'dashboard/modules/contact/ContactMergeModal.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import NextButton from 'dashboard/components-next/button/Button.vue';
import VoiceCallButton from 'dashboard/components-next/Contacts/VoiceCallButton.vue';

import {
  isAConversationRoute,
  isAInboxViewRoute,
  getConversationDashboardRoute,
} from '../../../../helper/routeHelpers';
import { emitter } from 'shared/helpers/mitt';

export default {
  components: {
    NextButton,
    ContactInfoRow,
    EditContact,
    Avatar,
    ComposeConversation,
    SocialIcons,
    ContactMergeModal,
    VoiceCallButton,
  },
  props: {
    contact: {
      type: Object,
      default: () => ({}),
    },
    showAvatar: {
      type: Boolean,
      default: true,
    },
  },
  emits: ['panelClose'],
  setup() {
    const { isAdmin } = useAdmin();
    return {
      isAdmin,
    };
  },
  data() {
    return {
      showEditModal: false,
      showMergeModal: false,
      showDeleteModal: false,
      spamStateOverride: null,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'contacts/getUIFlags',
      currentChat: 'getSelectedChat',
    }),
    effectiveChat() {
      return this.spamStateOverride
        ? { ...this.currentChat, ...this.spamStateOverride }
        : this.currentChat;
    },
    isSpam() {
      return !!this.effectiveChat?.is_spam;
    },
    wasSpam() {
      return (
        !!this.effectiveChat?.mark_as_not_spam && !this.effectiveChat?.is_spam
      );
    },
    contactProfileLink() {
      return `/app/accounts/${this.$route.params.accountId}/contacts/${this.contact.id}`;
    },
    additionalAttributes() {
      return this.contact.additional_attributes || {};
    },
    location() {
      const {
        country = '',
        city = '',
        country_code: countryCode,
      } = this.additionalAttributes;
      const cityAndCountry = [city, country].filter(item => !!item).join(', ');

      if (!cityAndCountry) {
        return '';
      }
      return this.findCountryFlag(countryCode, cityAndCountry);
    },
    socialProfiles() {
      const {
        social_profiles: socialProfiles,
        screen_name: twitterScreenName,
        social_telegram_user_name: telegramUsername,
      } = this.additionalAttributes;
      return {
        twitter: twitterScreenName,
        telegram: telegramUsername,
        ...(socialProfiles || {}),
      };
    },
    // Delete Modal
    confirmDeleteMessage() {
      return ` ${this.contact.name}?`;
    },
  },
  watch: {
    'contact.id': {
      handler(id) {
        this.$store.dispatch('contacts/fetchContactableInbox', id);
      },
      immediate: true,
    },
  },
  methods: {
    dynamicTime,
    toggleEditModal() {
      this.showEditModal = !this.showEditModal;
    },
    openComposeConversationModal(toggleFn) {
      toggleFn();
      // Flag to prevent triggering drag n drop,
      // When compose modal is active
      emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, true);
    },
    closeComposeConversationModal() {
      // Flag to enable drag n drop,
      // When compose modal is closed
      emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, false);
    },
    toggleDeleteModal() {
      this.showDeleteModal = !this.showDeleteModal;
    },
    confirmDeletion() {
      this.deleteContact(this.contact);
      this.closeDelete();
    },
    closeDelete() {
      this.showDeleteModal = false;
      this.showEditModal = false;
    },
    findCountryFlag(countryCode, cityAndCountry) {
      try {
        if (!countryCode) {
          return `${cityAndCountry} 🌎`;
        }

        const code = countryCode?.toLowerCase();
        return `${cityAndCountry} <span class="fi fi-${code} size-3.5"></span>`;
      } catch (error) {
        return '';
      }
    },
    async deleteContact({ id }) {
      try {
        await this.$store.dispatch('contacts/delete', id);
        this.$emit('panelClose');
        useAlert(this.$t('DELETE_CONTACT.API.SUCCESS_MESSAGE'));

        if (isAConversationRoute(this.$route.name)) {
          this.$router.push({
            name: getConversationDashboardRoute(this.$route.name),
          });
        } else if (isAInboxViewRoute(this.$route.name)) {
          this.$router.push({
            name: 'inbox_view',
          });
        } else if (this.$route.name !== 'contacts_dashboard') {
          this.$router.push({
            name: 'contacts_dashboard',
          });
        }
      } catch (error) {
        useAlert(
          error.message
            ? error.message
            : this.$t('DELETE_CONTACT.API.ERROR_MESSAGE')
        );
      }
    },
    closeMergeModal() {
      this.showMergeModal = false;
    },
    openMergeModal() {
      this.showMergeModal = true;
    },
    async markAsNotSpam() {
      try {
        this.spamStateOverride = {
          is_spam: false,
          stop_follow_up: false,
          mark_as_not_spam: true,
        };

        await this.$store.dispatch('bulkActions/process', {
          type: 'Conversation',
          ids: [this.currentChat.id],
          fields: {
            is_spam: false,
            stop_follow_up: false,
            mark_as_not_spam: true,
          },
        });

        const conversationId = this.currentChat.id;
        await this.$store.dispatch('fetchLatestMessages', { conversationId });
        await new Promise(resolve => setTimeout(resolve, 750));
        await this.$store.dispatch('fetchLatestMessages', { conversationId });
        await new Promise(resolve => setTimeout(resolve, 1500));
        await this.$store.dispatch('fetchLatestMessages', { conversationId });

        await this.$store.dispatch('getConversation', conversationId);
        await new Promise(resolve => setTimeout(resolve, 750));
        await this.$store.dispatch('getConversation', conversationId);
        this.spamStateOverride = null;
        this.$store.dispatch('bulkActions/clearSelectedConversationIds');
        useAlert(this.$t('BULK_ACTION.MARK_AS_NOT_SPAM_SUCCESFUL'));
      } catch (error) {
        this.spamStateOverride = null;
        useAlert(this.$t('BULK_ACTION.MARK_AS_NOT_SPAM_FAILED'));
      }
    },
    async markAsSpam() {
      try {
        this.spamStateOverride = { is_spam: true, mark_as_not_spam: false };

        await this.$store.dispatch('bulkActions/process', {
          type: 'Conversation',
          ids: [this.currentChat.id],
          fields: {
            is_spam: true,
            mark_as_not_spam: false,
            stop_follow_up: true,
          },
        });
        this.spamStateOverride = null;
        this.$store.dispatch('bulkActions/clearSelectedConversationIds');
        useAlert(this.$t('BULK_ACTION.MARK_AS_SPAM_SUCCESFUL'));
      } catch (error) {
        this.spamStateOverride = null;
        useAlert(this.$t('BULK_ACTION.MARK_AS_SPAM_FAILED'));
      }
    },
    async copyToClipboard(text) {
      try {
        await navigator.clipboard.writeText(text);
        useAlert(this.$t('CONTACT_PANEL.COPY_SUCCESS'));
      } catch (error) {
        useAlert(this.$t('CONTACT_PANEL.COPY_FAILED'));
      }
    },
  },
};
</script>

<template>
  <div class="relative flex flex-col items-center w-full px-5 py-6 text-center">
    <!-- Contact Label -->
    <span class="absolute top-4 left-5 text-[14px] font-medium text-slate-800 dark:text-slate-100">
      {{ $t('CONVERSATION.SIDEBAR.CONTACT') || 'Contact' }}
    </span>
    <!-- Close Button -->
    <NextButton
      v-tooltip.left="$t('GENERAL.CLOSE')"
      icon="i-lucide-x"
      ghost
      slate
      class="absolute top-2 right-4 !text-slate-400 hover:!text-slate-600 hover:bg-slate-100 dark:hover:bg-white/5 !rounded-full transition-all"
      @click="$emit('panelClose')"
    />
    <!-- Avatar and Name Section -->
    <div class="flex flex-col items-center w-full gap-4 mb-2 mt-14">
      <div class="p-1 rounded-full shadow-sm">
        <Avatar
          v-if="showAvatar"
          :src="contact.thumbnail"
          :name="contact.name"
          :status="contact.availability_status"
          :size="80"
          hide-offline-status
          rounded-full
        />
      </div>
      <div class="flex flex-col items-center min-w-0">
        <div class="flex items-center gap-2 mb-1">
          <h2 class="text-xl font-black text-slate-900 dark:text-white truncate leading-tight">
            {{ contact.name }}
          </h2>
          <div class="flex items-center gap-1.5">
            <span
              v-if="contact.created_at"
              v-tooltip.top="
                `${$t('CONTACT_PANEL.CREATED_AT_LABEL')} ${dynamicTime(
                  contact.created_at
                )}`
              "
              class="i-lucide-info text-sm text-slate-400 hover:text-slate-600 transition-colors"
            />
            <a
              v-tooltip.top="'View Profile'"
              :href="contactProfileLink"
              target="_blank"
              rel="noopener nofollow noreferrer"
              class="text-slate-400 hover:text-blue-500 transition-colors"
            >
              <span class="i-lucide-external-link size-4" />
            </a>
          </div>
        </div>
        <p v-if="additionalAttributes.description" class="text-xs text-slate-500 dark:text-slate-400 mt-1 max-w-[240px] break-words">
          {{ additionalAttributes.description }}
        </p>
      </div>
    </div>

    <!-- Divider -->
    <div class="w-full h-px bg-slate-100 dark:bg-white/10 my-6" />

    <!-- Info Rows Grid -->
    <div class="flex flex-col w-full gap-4 px-4 text-left">
      <ContactInfoRow
        :href="contact.email ? `mailto:${contact.email}` : ''"
        :value="contact.email"
        icon="mail"
        emoji="✉️"
        :title="$t('CONTACT_PANEL.EMAIL_ADDRESS')"
        show-copy
      />
      <ContactInfoRow
        :href="contact.phone_number ? `tel:${contact.phone_number}` : ''"
        :value="contact.phone_number"
        icon="call"
        emoji="📞"
        :title="$t('CONTACT_PANEL.PHONE_NUMBER')"
        show-copy
      />
      <ContactInfoRow
        v-if="contact.identifier"
        :value="contact.identifier"
        icon="contact-identify"
        emoji="🪪"
        :title="$t('CONTACT_PANEL.IDENTIFIER')"
      />
      <ContactInfoRow
        :value="additionalAttributes.company_name"
        icon="building-bank"
        emoji="🏢"
        :title="$t('CONTACT_PANEL.COMPANY')"
      />
      <ContactInfoRow
        v-if="location || additionalAttributes.location"
        :value="location || additionalAttributes.location"
        icon="map"
        emoji="🌍"
        :title="$t('CONTACT_PANEL.LOCATION')"
      />
      <SocialIcons :social-profiles="socialProfiles" />
    </div>

    <!-- Action Buttons -->
    <div class="flex flex-wrap items-center justify-center w-full mt-8 gap-3 px-2">
      <ComposeConversation
        :contact-id="String(contact.id)"
        is-modal
        @close="closeComposeConversationModal"
      >
        <template #trigger="{ toggle }">
          <NextButton
            v-tooltip.top="$t('CONTACT_PANEL.NEW_MESSAGE')"
            icon="i-ph-chat-circle-dots"
            slate
            faded
            class="!rounded-full shadow-sm hover:!bg-slate-100 dark:hover:!bg-white/10"
            @click="openComposeConversationModal(toggle)"
          />
        </template>
      </ComposeConversation>

      <VoiceCallButton
        :phone="contact.phone_number"
        :contact-id="contact.id"
        icon="i-ph-phone"
        :tooltip-label="$t('CONTACT_PANEL.CALL')"
        slate
        faded
        class="!rounded-full shadow-sm hover:!bg-slate-100 dark:hover:!bg-white/10 !size-[38px] flex items-center justify-center"
      />
      
      <NextButton
        v-tooltip.top="$t('EDIT_CONTACT.BUTTON_LABEL')"
        icon="i-ph-pencil-simple"
        slate
        faded
        class="!rounded-full shadow-sm hover:!bg-slate-100 dark:hover:!bg-white/10"
        @click="toggleEditModal"
      />

      <NextButton
        v-tooltip.top="$t('CONTACT_PANEL.MERGE_CONTACT') || 'Merge Contact'"
        icon="i-ph-arrows-merge"
        slate
        faded
        class="!rounded-full shadow-sm hover:!bg-slate-100 dark:hover:!bg-white/10"
        :disabled="uiFlags.isMerging"
        @click="openMergeModal"
      />

      <NextButton
        v-if="isSpam"
        v-tooltip.top="$t('BULK_ACTION.MARK_AS_NOT_SPAM')"
        icon="i-ph-shield-check"
        slate
        faded
        class="!rounded-full shadow-sm hover:!bg-slate-100 dark:hover:!bg-white/10"
        @click="markAsNotSpam"
      />

      <NextButton
        v-if="wasSpam"
        v-tooltip.top="$t('BULK_ACTION.MARK_AS_SPAM')"
        icon="i-ph-shield-warning"
        slate
        faded
        class="!rounded-full shadow-sm hover:!bg-slate-100 dark:hover:!bg-white/10"
        @click="markAsSpam"
      />

      <NextButton
        v-if="isAdmin"
        v-tooltip.top="$t('DELETE_CONTACT.BUTTON_LABEL')"
        icon="i-ph-trash"
        slate
        faded
        ruby
        class="!rounded-full !bg-red-50 hover:!bg-red-100 dark:!bg-red-500/10 dark:hover:!bg-red-500/20 shadow-sm"
        :disabled="uiFlags.isDeleting"
        @click="toggleDeleteModal"
      />
    </div>

    <!-- Modals -->
    <EditContact
      v-if="showEditModal"
      :show="showEditModal"
      :contact="contact"
      @cancel="toggleEditModal"
    />
    <ContactMergeModal
      v-if="showMergeModal"
      :primary-contact="contact"
      :show="showMergeModal"
      @close="closeMergeModal"
    />
    <woot-delete-modal
      v-if="showDeleteModal"
      v-model:show="showDeleteModal"
      :on-close="closeDelete"
      :on-confirm="confirmDeletion"
      :title="$t('DELETE_CONTACT.CONFIRM.TITLE')"
      :message="$t('DELETE_CONTACT.CONFIRM.MESSAGE')"
      :message-value="confirmDeleteMessage"
      :confirm-text="$t('DELETE_CONTACT.CONFIRM.YES')"
      :reject-text="$t('DELETE_CONTACT.CONFIRM.NO')"
    />
  </div>
</template>
