<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import {
  DuplicateContactException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useAdmin } from 'dashboard/composables/useAdmin';
import ContactInfoRow from './ContactInfoRow.vue';
import Avatar from 'next/avatar/Avatar.vue';
import SocialIcons from './SocialIcons.vue';
import EditContact from './EditContact.vue';
import ContactMergeModal from 'dashboard/modules/contact/ContactMergeModal.vue';
import ContactDeleteModal from 'dashboard/modules/contact/ContactDeleteModal.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import VoiceCallButton from 'dashboard/components-next/Contacts/VoiceCallButton.vue';
import InlineInput from 'dashboard/components-next/inline-input/InlineInput.vue';

export default {
  components: {
    NextButton,
    ContactInfoRow,
    EditContact,
    Avatar,
    ComposeConversation,
    SocialIcons,
    ContactMergeModal,
    ContactDeleteModal,
    VoiceCallButton,
    InlineInput,
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
      isEditingName: false,
      editName: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'contacts/getUIFlags',
      currentChat: 'getSelectedChat',
    }),

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

      const telegram = socialProfiles?.telegram || telegramUsername || '';
      const twitter = socialProfiles?.twitter || twitterScreenName || '';

      return {
        ...(socialProfiles || {}),
        twitter,
        telegram,
      };
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
    startEditingName() {
      this.editName = this.contact.name || '';
      this.isEditingName = true;
      this.$nextTick(() => {
        this.$refs.nameInput?.focus();
      });
    },
    saveNameEdit() {
      if (!this.isEditingName) return;
      this.isEditingName = false;
      const trimmed = this.editName.trim();
      if (trimmed && trimmed !== this.contact.name) {
        this.updateContactField({ name: trimmed });
      }
    },
    cancelNameEdit() {
      this.isEditingName = false;
    },
    onFieldUpdate(field, value) {
      this.updateContactField({ [field]: value });
    },
    async updateContactField(attrs) {
      const contactId = this.contact.id;
      try {
        await this.$store.dispatch('contacts/update', {
          id: contactId,
          ...attrs,
        });
        useAlert(this.$t('CONTACT_FORM.SUCCESS_MESSAGE'));
        await this.$store.dispatch('contacts/fetchContactableInbox', contactId);
      } catch (error) {
        if (error instanceof DuplicateContactException) {
          const detail = error.contactErrorDetail;
          if (detail) {
            useAlert(detail);
          } else {
            const invalidAttrs = Array.isArray(error.data) ? error.data : [];
            if (invalidAttrs.includes('email')) {
              useAlert(this.$t('CONTACT_FORM.FORM.EMAIL_ADDRESS.DUPLICATE'));
            } else if (invalidAttrs.includes('phone_number')) {
              useAlert(this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.DUPLICATE'));
            } else {
              useAlert(this.$t('CONTACT_FORM.ERROR_MESSAGE'));
            }
          }
        } else if (error instanceof ExceptionWithMessage) {
          useAlert(error.data);
        } else {
          useAlert(error.message || this.$t('CONTACT_FORM.ERROR_MESSAGE'));
        }
      }
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
  },
};
</script>

<template>
  <div class="relative items-center w-full p-4">
    <div class="flex flex-col w-full gap-2 text-left rtl:text-right">
      <div class="flex flex-row justify-between">
        <Avatar
          v-if="showAvatar"
          :src="contact.thumbnail"
          :name="contact.name"
          :status="contact.availability_status"
          :size="48"
          hide-offline-status

        />
      </div>

      <div class="flex flex-col items-start gap-1.5 min-w-0 w-full">
        <div v-if="showAvatar" class="flex items-center w-full min-w-0 gap-3">
          <InlineInput
            v-if="isEditingName"
            ref="nameInput"
            v-model="editName"
            custom-input-class="!text-base !font-medium"
            class="!w-fit"
            @enter-press="saveNameEdit"
            @escape-press="cancelNameEdit"
            @blur="saveNameEdit"
          />
          <h3
            v-else
            class="group/name flex-shrink max-w-full min-w-0 my-0 text-base capitalize break-words text-n-slate-12 cursor-pointer hover:text-n-slate-12/80"
            :title="$t('CONTACT_PANEL.CLICK_TO_EDIT')"
            @click="startEditingName"
          >
            {{ contact.name }}
            <span
              class="i-lucide-pencil text-xs text-n-slate-10 opacity-0 group-hover/name:opacity-100 transition-opacity ml-1 align-middle"
            />
          </h3>
          <div class="flex flex-row items-center gap-2">
            <span
              v-if="contact.created_at"
              v-tooltip.left="
                `${$t('CONTACT_PANEL.CREATED_AT_LABEL')} ${dynamicTime(
                  contact.created_at
                )}`
              "
              class="i-lucide-info text-sm text-n-slate-10"
            />
            <a
              :href="contactProfileLink"
              target="_blank"
              rel="noopener nofollow noreferrer"
              class="leading-3"
            >
              <span class="i-lucide-external-link text-sm text-n-slate-10" />
            </a>
          </div>
        </div>

        <a
          v-if="socialProfiles.instagram"
          :href="`https://instagram.com/${socialProfiles.instagram}`"
          target="_blank"
          rel="noopener nofollow noreferrer"
          class="flex items-center gap-1 text-xs text-n-slate-11 hover:text-n-slate-12 transition-colors -mt-1"
        >
          <span>{{ socialProfiles.instagram }}</span>
        </a>

        <p v-if="additionalAttributes.description" class="break-words mb-0.5">
          {{ additionalAttributes.description }}
        </p>
        <div class="flex flex-col items-start w-full gap-2">
          <ContactInfoRow
            :href="contact.email ? `mailto:${contact.email}` : ''"
            :value="contact.email"
            icon="mail"
            emoji="✉️"
            :title="$t('CONTACT_PANEL.EMAIL_ADDRESS')"
            show-copy
            editable
            @update="value => onFieldUpdate('email', value)"
          />
          <ContactInfoRow
            :href="contact.phone_number ? `tel:${contact.phone_number}` : ''"
            :value="contact.phone_number"
            icon="call"
            emoji="📞"
            :title="$t('CONTACT_PANEL.PHONE_NUMBER')"
            show-copy
            editable
            @update="value => onFieldUpdate('phone_number', value)"
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
            editable
            @update="
              value =>
                updateContactField({
                  additional_attributes: {
                    ...additionalAttributes,
                    company_name: value,
                  },
                })
            "
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
      </div>
      <div class="flex items-center w-full mt-0.5 gap-2">
        <ComposeConversation :contact-id="String(contact.id)">
          <template #trigger>
            <NextButton
              v-tooltip.top-end="$t('CONTACT_PANEL.NEW_MESSAGE')"
              icon="i-ph-chat-circle-dots"
              slate
              faded
              sm
            />
          </template>
        </ComposeConversation>
        <VoiceCallButton
          :phone="contact.phone_number"
          :contact-id="contact.id"
          :conversation-id="currentChat?.id"
          icon="i-lucide-phone"
          sm
          faded
          slate
          :tooltip-label="$t('CONTACT_PANEL.CALL')"
        />
        <NextButton
          v-tooltip.top-end="$t('EDIT_CONTACT.BUTTON_LABEL')"
          icon="i-ph-pencil-simple"
          slate
          faded
          sm
          @click="toggleEditModal"
        />
        <ContactMergeModal :primary-contact="contact">
          <template #trigger>
            <NextButton
              v-tooltip.top-end="$t('CONTACT_PANEL.MERGE_CONTACT')"
              icon="i-ph-arrows-merge"
              slate
              faded
              sm
              :disabled="uiFlags.isMerging"
            />
          </template>
        </ContactMergeModal>
        <ContactDeleteModal
          v-if="isAdmin"
          :contact="contact"
          @deleted="$emit('panelClose')"
        >
          <template #trigger>
            <NextButton
              v-tooltip.top-end="$t('DELETE_CONTACT.BUTTON_LABEL')"
              icon="i-ph-trash"
              slate
              faded
              sm
              ruby
              :disabled="uiFlags.isDeleting"
            />
          </template>
        </ContactDeleteModal>
      </div>
      <EditContact
        :show="showEditModal"
        :contact="contact"
        @cancel="toggleEditModal"
      />
    </div>
  </div>

  <Teleport to="body">
    <div
      v-if="showSentimentModal"
      class="fixed inset-0 z-[9999] flex items-center justify-center"
      @click.self="closeSentimentModal"
    >
      <div class="absolute inset-0 bg-black/50 dark:bg-black/70" />
      <div class="relative bg-white dark:bg-slate-800 rounded-xl shadow-2xl w-full max-w-md mx-4 p-6">
        <div class="flex items-start justify-between mb-4">
          <div>
            <h3 class="text-base font-bold text-slate-900 dark:text-white">
              {{ $t('CONTACT_PANEL.UPDATE_SENTIMENT.TITLE') }}
            </h3>
            <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
              {{ $t('CONTACT_PANEL.UPDATE_SENTIMENT.DESCRIPTION') }}
            </p>
          </div>
          <button
            class="ml-4 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 transition-colors"
            @click="closeSentimentModal"
          >
            <span class="i-lucide-x size-5" />
          </button>
        </div>
        <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
          {{ $t('CONTACT_PANEL.UPDATE_SENTIMENT.REASON_LABEL') }}
        </label>
        <textarea
          v-model="sentimentReason"
          :placeholder="$t('CONTACT_PANEL.UPDATE_SENTIMENT.REASON_PLACEHOLDER')"
          rows="3"
          class="w-full text-sm rounded-lg border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 px-3 py-2 resize-none focus:outline-none focus:ring-2 focus:ring-amber-400 dark:focus:ring-amber-500"
        />
        <div class="flex items-center justify-end gap-3 mt-5">
          <button
            type="button"
            class="px-4 py-2 rounded-lg text-sm font-medium bg-slate-100 hover:bg-slate-200 dark:bg-slate-700 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-200 transition-colors"
            @click="closeSentimentModal"
          >
            {{ $t('CONTACT_PANEL.UPDATE_SENTIMENT.CANCEL') }}
          </button>
          <button
            type="button"
            :disabled="isUpdatingSentiment"
            class="px-4 py-2 rounded-lg text-sm font-semibold bg-n-blue-10 hover:bg-n-blue-7 active:bg-blue-800 text-white shadow-sm disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            @click="submitSentimentUpdate"
          >
            {{ isUpdatingSentiment
              ? $t('CONTACT_PANEL.UPDATE_SENTIMENT.SUBMITTING')
              : $t('CONTACT_PANEL.UPDATE_SENTIMENT.SUBMIT') }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
