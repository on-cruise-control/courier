<script setup>
import { computed, onUnmounted, ref } from 'vue';
import { useToggle } from '@vueuse/core';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';
import EmailTranscriptModal from './EmailTranscriptModal.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

import {
  CMD_MUTE_CONVERSATION,
  CMD_SEND_TRANSCRIPT,
  CMD_UNMUTE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

// No props needed as we're getting currentChat from the store directly
const store = useStore();
const { t } = useI18n();

const [showEmailActionsModal, toggleEmailModal] = useToggle(false);
const [showActionsDropdown, toggleDropdown] = useToggle(false);

const currentChat = computed(() => store.getters.getSelectedChat);
const isBlacklisted = computed(() => currentChat.value.is_blacklisted);
const blockConfirmDialogRef = ref(null);
const unblockConfirmDialogRef = ref(null);

const postUrl = computed(() => {
  const attrs = currentChat.value?.additional_attributes || {};
  const type = attrs.type;
  const isComment =
    type === 'instagram_comments' ||
    type === 'facebook_comments' ||
    type === 'feed_comments';
  return isComment ? attrs.post_url || '' : '';
});

const postPlatformIcon = computed(() => {
  const type = currentChat.value?.additional_attributes?.type;
  return type === 'instagram_comments'
    ? 'i-ri-instagram-line'
    : 'i-ri-facebook-circle-fill';
});

const openPostUrl = () => {
  window.open(postUrl.value, '_blank', 'noopener,noreferrer');
};

const setBlacklisted = async wasBlacklisted => {
  try {
    await store.dispatch('bulkActions/process', {
      type: 'Conversation',
      ids: [currentChat.value.id],
      fields: { is_blacklisted: !wasBlacklisted },
    });
    useAlert(
      wasBlacklisted
        ? t('CONVERSATION.UNBLOCK_SUCCESS')
        : t('CONVERSATION.BLOCK_SUCCESS')
    );
  } catch (error) {
    useAlert(
      wasBlacklisted
        ? t('CONVERSATION.UNBLOCK_ERROR')
        : t('CONVERSATION.BLOCK_ERROR')
    );
  }
};

const toggleBlacklist = () => {
  if (isBlacklisted.value) {
    unblockConfirmDialogRef.value?.open();
  } else {
    blockConfirmDialogRef.value?.open();
  }
};

const handleBlockConfirm = () => {
  setBlacklisted(false);
  blockConfirmDialogRef.value?.close();
  document.activeElement?.blur();
};

const handleUnblockConfirm = () => {
  setBlacklisted(true);
  unblockConfirmDialogRef.value?.close();
  document.activeElement?.blur();
};

const actionMenuItems = computed(() => [
  {
    icon: 'i-lucide-share',
    label: t('CONTACT_PANEL.SEND_TRANSCRIPT'),
    action: 'send_transcript',
    value: 'send_transcript',
  },
]);

const handleActionClick = ({ action }) => {
  toggleDropdown(false);

  if (action === 'send_transcript') {
    toggleEmailModal();
  }
};

// These functions are needed for the event listeners
const mute = () => {
  store.dispatch('muteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
};

const unmute = () => {
  store.dispatch('unmuteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
};

emitter.on(CMD_MUTE_CONVERSATION, mute);
emitter.on(CMD_UNMUTE_CONVERSATION, unmute);
emitter.on(CMD_SEND_TRANSCRIPT, toggleEmailModal);

onUnmounted(() => {
  emitter.off(CMD_MUTE_CONVERSATION, mute);
  emitter.off(CMD_UNMUTE_CONVERSATION, unmute);
  emitter.off(CMD_SEND_TRANSCRIPT, toggleEmailModal);
});
</script>

<template>
  <div class="relative flex items-center gap-2 actions--container">
    <ButtonV4
      v-if="postUrl"
      :label="$t('CONTACT_PANEL.VIEW_POST')"
      :icon="postPlatformIcon"
      size="sm"
      color="slate"
      no-animation
      class="shadow"
      @click="openPostUrl"
    />
    <ResolveAction
      :conversation-id="currentChat.id"
      :status="currentChat.status"
    />
    <ButtonV4
      v-tooltip="
        isBlacklisted ? $t('CONVERSATION.UNBLOCK') : $t('CONVERSATION.BLOCK')
      "
      :label="
        isBlacklisted
          ? $t('CONVERSATION.UNBLOCK_BUTTON')
          : $t('CONVERSATION.BLOCK_BUTTON')
      "
      size="sm"
      color="slate"
      no-animation
      class="shadow"
      @click="toggleBlacklist"
    />
    <div
      v-on-clickaway="() => toggleDropdown(false)"
      class="relative flex items-center group"
    >
      <ButtonV4
        v-tooltip="$t('CONVERSATION.HEADER.MORE_ACTIONS')"
        size="sm"
        variant="ghost"
        color="slate"
        icon="i-lucide-more-vertical"
        class="rounded-md group-hover:bg-n-alpha-2"
        @click="toggleDropdown()"
      />
      <DropdownMenu
        v-if="showActionsDropdown"
        :menu-items="actionMenuItems"
        class="mt-1 ltr:right-0 rtl:left-0 top-full"
        @action="handleActionClick"
      />
    </div>
    <EmailTranscriptModal
      v-if="showEmailActionsModal"
      :show="showEmailActionsModal"
      :current-chat="currentChat"
      @cancel="toggleEmailModal"
    />
    <Dialog
      ref="blockConfirmDialogRef"
      type="alert"
      :title="$t('CONVERSATION.BLOCK_CONFIRM.TITLE')"
      :description="$t('CONVERSATION.BLOCK_CONFIRM.DESCRIPTION')"
      :confirm-button-label="$t('CONVERSATION.BLOCK_CONFIRM.CONFIRM')"
      @confirm="handleBlockConfirm"
    />
    <Dialog
      ref="unblockConfirmDialogRef"
      type="alert"
      :title="$t('CONVERSATION.UNBLOCK_CONFIRM.TITLE')"
      :description="$t('CONVERSATION.UNBLOCK_CONFIRM.DESCRIPTION')"
      :confirm-button-label="$t('CONVERSATION.UNBLOCK_CONFIRM.CONFIRM')"
      @confirm="handleUnblockConfirm"
    />
  </div>
</template>
