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
        this.spamStateOverride = { is_spam: false, mark_as_not_spam: true };

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
  <div class="relative flex flex-col items-center w-full p-6 pt-10 text-center">
    <!-- Avatar and Name Section -->
    <div class="flex flex-col items-center w-full mb-6">
      <div class="mb-4">
        <Avatar
          v-if="showAvatar"
          :src="contact.thumbnail"
          :name="contact.name"
          :status="contact.availability_status"
          :size="80"
          hide-offline-status
          rounded-full
          class="rounded-full ring-4 ring-white dark:ring-transparent shadow-md"
        />
      </div>

      <!-- Name & Icons -->
      <div class="flex flex-row items-center justify-center gap-1.5 w-full">
        <h3 class="text-xl font-bold text-slate-800 dark:text-slate-100 leading-tight">
          {{ contact.name }}
        </h3>
        <div class="flex flex-row items-center gap-1.5 pt-1">
          <span
            v-if="contact.created_at"
            v-tooltip.left="
              `${$t('CONTACT_PANEL.CREATED_AT_LABEL')} ${dynamicTime(
                contact.created_at
              )}`
            "
            class="i-lucide-info text-sm text-slate-400 hover:text-slate-600 transition-colors"
          />
          <a
            :href="contactProfileLink"
            target="_blank"
            rel="noopener nofollow noreferrer"
            class="leading-3"
          >
            <span class="i-lucide-external-link text-sm text-slate-400 hover:text-slate-600 transition-colors" />
          </a>
        </div>
      </div>

      <!-- Bio/Description -->
      <p v-if="contact.description" class="text-[14px] font-medium text-slate-700 dark:text-slate-200 mt-1 max-w-[90%] truncate">
        {{ contact.description }}
      </p>
    </div>

    <div class="w-full h-px bg-slate-100 dark:bg-white/5 mb-6" />

    <!-- Info Rows -->
    <div class="flex flex-col items-start w-full px-4 overflow-hidden">
      <!-- Email Row -->
      <div v-if="contact.email" style="display: flex !important; flex-direction: row !important; align-items: center !important; width: 100% !important; flex-wrap: nowrap !important;" class="group py-1">
        <span class="i-ph-envelope-simple-bold text-slate-400 text-base shrink-0" style="width: 24px !important;" />
        <a :href="`mailto:${contact.email}`" class="text-[13px] font-medium text-slate-700 dark:text-slate-300 hover:text-blue-600 transition-colors truncate" style="white-space: nowrap !important; margin-right: 8px !important;">
          {{ contact.email }}
        </a>
        <NextButton
          v-tooltip.top="$t('CONTACT_PANEL.COPY_EMAIL')"
          icon="i-lucide-copy"
          slate
          faded
          class="!p-1 !h-5 !w-5 !min-h-0 !min-w-0 !rounded-md opacity-0 group-hover:opacity-100 transition-opacity shrink-0"
          @click="copyToClipboard(contact.email)"
        />
      </div>
      <div v-else style="display: flex !important; align-items: center !important; width: 100% !important; padding: 2px 0 !important;">
        <span class="i-ph-envelope-simple-bold text-slate-400 text-base shrink-0" style="width: 24px !important;" />
        <span class="text-[13px] font-medium text-slate-400 italic">Not Available</span>
      </div>

      <!-- Phone Row -->
      <div v-if="contact.phone_number" class="group flex items-center w-full py-1.5 gap-2.5 overflow-hidden">
        <span class="i-ph-phone-bold text-slate-400 text-base shrink-0" style="width: 24px !important;" />
        
        <div class="flex items-center justify-center">
          {{ contact.phone_number }}
          
          <div class="flex items-center gap-1.5 shrink-0 pl-1">
            <NextButton
              v-tooltip.top="$t('CONTACT_PANEL.COPY_PHONE')"
              icon="i-lucide-copy"
              slate
              faded
              class="!p-1 !h-5 !w-5 !min-h-0 !min-w-0 !rounded-md opacity-0 group-hover:opacity-100 transition-opacity shrink-0"
              @click="copyToClipboard(contact.phone_number)"
            />
            <VoiceCallButton
              :phone="contact.phone_number"
              :contact-id="contact.id"
              icon="i-ph-phone-fill"
              size="sm"
              :tooltip-label="$t('CONTACT_PANEL.CALL')"
              class="!rounded-full !bg-blue-600/10 dark:!bg-blue-500/20 !text-blue-600 dark:!text-blue-400 border-0 !p-1 !h-7 !w-7 !min-h-0 !min-w-0 flex items-center justify-center transition-all hover:scale-105 active:scale-95 shadow-none hover:!bg-blue-600 hover:!text-white shrink-0"
            />
          </div>
        </div>

        <a :href="`tel:${contact.phone_number}`" class="w-fit min-w-0 text-[13px] font-medium text-slate-700 dark:text-slate-300 hover:text-blue-600 transition-colors truncate" style="white-space: nowrap !important;">
        </a>
      </div>
      <div v-else style="display: flex !important; align-items: center !important; width: 100% !important; padding: 2px 0 !important;">
        <span class="i-ph-phone-bold text-slate-400 text-base shrink-0" style="width: 24px !important;" />
        <span class="text-[13px] font-medium text-slate-400 italic">Not Available</span>
      </div>

      <!-- Company Row -->
      <div v-if="additionalAttributes.company_name" style="display: flex !important; flex-direction: row !important; align-items: center !important; width: 100% !important; flex-wrap: nowrap !important;" class="py-1">
        <span class="i-ph-buildings-bold text-slate-400 text-base shrink-0" style="width: 24px !important;" />
        <span class="text-[13px] font-medium text-slate-700 dark:text-slate-300 truncate" style="white-space: nowrap !important;">
          {{ additionalAttributes.company_name }}
        </span>
      </div>
      <div v-else style="display: flex !important; align-items: center !important; width: 100% !important; padding: 2px 0 !important;">
        <span class="i-ph-buildings-bold text-slate-400 text-base shrink-0" style="width: 24px !important;" />
        <span class="text-[13px] font-medium text-slate-400 italic">Not Available</span>
      </div>

      <!-- Location Row -->
      <div v-if="location" style="display: flex !important; flex-direction: row !important; align-items: center !important; width: 100% !important; flex-wrap: nowrap !important;" class="py-1">
        <span class="i-ph-map-pin-bold text-slate-400 text-base shrink-0" style="width: 24px !important;" />
        <span class="text-[13px] font-medium text-slate-700 dark:text-slate-300 truncate" style="white-space: nowrap !important;" v-html="location" />
      </div>

      <SocialIcons v-if="Object.values(socialProfiles).some(v => !!v)" :social-profiles="socialProfiles" class="mt-4" />
    </div>

    <!-- Action Buttons -->
    <div class="flex items-center justify-center w-full mt-4 gap-3">
      <ComposeConversation
        :contact-id="String(contact.id)"
        is-modal
        @close="closeComposeConversationModal"
      >
        <template #trigger="{ toggle }">
          <NextButton
            v-tooltip.top-end="$t('CONTACT_PANEL.NEW_MESSAGE')"
            icon="i-ph-chat-circle-dots"
            slate
            faded
            sm
            class="!rounded-full shadow-sm hover:!bg-white dark:hover:!bg-white/5"
            @click="openComposeConversationModal(toggle)"
          />
        </template>
      </ComposeConversation>
      <NextButton
        v-tooltip.top-end="$t('EDIT_CONTACT.BUTTON_LABEL')"
        icon="i-ph-pencil-simple"
        slate
        faded
        sm
        class="!rounded-full shadow-sm hover:!bg-white dark:hover:!bg-white/5"
        @click="toggleEditModal"
      />
      <NextButton
        v-tooltip.top-end="$t('CONTACT_PANEL.MERGE_CONTACT')"
        icon="i-ph-arrows-merge"
        slate
        faded
        sm
        class="!rounded-full shadow-sm hover:!bg-white dark:hover:!bg-white/5"
        :disabled="uiFlags.isMerging"
        @click="openMergeModal"
      />
      <NextButton
        v-if="isSpam"
        v-tooltip.top-end="$t('BULK_ACTION.MARK_AS_NOT_SPAM')"
        icon="i-lucide-shield-check"
        slate
        faded
        sm
        class="!rounded-full shadow-sm hover:!bg-white dark:hover:!bg-white/5 text-green-600"
        @click="markAsNotSpam"
      />
      <NextButton
        v-if="wasSpam"
        v-tooltip.top-end="$t('BULK_ACTION.MARK_AS_SPAM')"
        icon="i-lucide-shield-alert"
        slate
        faded
        sm
        class="!rounded-full shadow-sm hover:!bg-white dark:hover:!bg-white/5 text-red-600"
        @click="markAsSpam"
      />
      <NextButton
        v-if="isAdmin"
        v-tooltip.top-end="$t('DELETE_CONTACT.BUTTON_LABEL')"
        icon="i-ph-trash"
        slate
        faded
        sm
        ruby
        class="!rounded-full shadow-sm hover:!bg-white dark:hover:!bg-white/5"
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
