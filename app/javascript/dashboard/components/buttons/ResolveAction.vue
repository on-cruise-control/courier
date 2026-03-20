<script setup>
import { ref, computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useEmitter } from 'dashboard/composables/emitter';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useAgentsList } from 'dashboard/composables/useAgentsList';

import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';
import MultiselectDropdownItems from 'shared/components/ui/MultiselectDropdownItems.vue';
import wootConstants from 'dashboard/constants/globals';
import {
  CMD_REOPEN_CONVERSATION,
  CMD_RESOLVE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

import ButtonGroup from 'dashboard/components-next/buttonGroup/ButtonGroup.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();

const arrowDownButtonRef = ref(null);
const isLoading = ref(false);

const [showActionsDropdown, toggleDropdown] = useToggle();
const closeDropdown = () => toggleDropdown(false);
const openDropdown = () => toggleDropdown(true);

const [showAgentDropdown, toggleAgentDropdown] = useToggle();
const closeAgentDropdown = () => toggleAgentDropdown(false);
const openAgentDropdown = () => toggleAgentDropdown(true);

const { agentsList } = useAgentsList();

const currentChat = computed(() => getters.getSelectedChat.value);

const isOpen = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.OPEN
);
const isPending = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.PENDING
);
const isResolved = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.RESOLVED
);
const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const showAdditionalActions = computed(
  () => !isPending.value && !isSnoozed.value
);

const showOpenButton = computed(() => {
  return isPending.value || isSnoozed.value;
});

const getConversationParams = () => {
  const allConversations = document.querySelectorAll(
    '.conversations-list .conversation'
  );

  const activeConversation = document.querySelector(
    'div.conversations-list div.conversation.active'
  );
  const activeConversationIndex = [...allConversations].indexOf(
    activeConversation
  );
  const lastConversationIndex = allConversations.length - 1;

  return {
    all: allConversations,
    activeIndex: activeConversationIndex,
    lastIndex: lastConversationIndex,
  };
};

const openSnoozeModal = () => {
  const ninja = document.querySelector('ninja-keys');
  ninja.open({ parent: 'snooze_conversation' });
};

const toggleStatus = (status, snoozedUntil) => {
  closeDropdown();
  isLoading.value = true;
  store
    .dispatch('toggleStatus', {
      conversationId: currentChat.value.id,
      status,
      snoozedUntil,
    })
    .then(() => {
      useAlert(t('CONVERSATION.CHANGE_STATUS'));
      isLoading.value = false;
    });
};

const onCmdOpenConversation = () => {
  toggleStatus(wootConstants.STATUS_TYPE.OPEN);
};

const onCmdResolveConversation = () => {
  toggleStatus(wootConstants.STATUS_TYPE.RESOLVED);
};

const keyboardEvents = {
  'Alt+KeyM': {
    action: () => arrowDownButtonRef.value?.$el.click(),
    allowOnFocusedInput: true,
  },
  'Alt+KeyE': {
    action: async () => {
      await toggleStatus(wootConstants.STATUS_TYPE.RESOLVED);
    },
  },
  '$mod+Alt+KeyE': {
    action: async event => {
      const { all, activeIndex, lastIndex } = getConversationParams();
      await toggleStatus(wootConstants.STATUS_TYPE.RESOLVED);

      if (activeIndex < lastIndex) {
        all[activeIndex + 1].click();
      } else if (all.length > 1) {
        all[0].click();
        document.querySelector('.conversations-list').scrollTop = 0;
      }
      event.preventDefault();
    },
  },
};

const currentUserId = computed(() => getters.getCurrentUserID.value);
const assignee = computed(() => currentChat.value?.meta?.assignee);

const onSelectAgent = (agent) => {
  closeAgentDropdown();
  isLoading.value = true;
  const agentId = agent ? agent.id : 0;
  store
    .dispatch('assignAgent', {
      conversationId: currentChat.value.id,
      agentId,
    })
    .then(() => {
      store.dispatch('setCurrentChatAssignee', agent);
      useAlert(t('CONVERSATION.CHANGE_AGENT'));
    })
    .finally(() => {
      isLoading.value = false;
    });
};

const onUnassign = () => {
  isLoading.value = true;
  store
    .dispatch('assignAgent', {
      conversationId: currentChat.value.id,
      agentId: 0,
    })
    .then(() => {
      useAlert(t('CONVERSATION.CHANGE_AGENT'));
    })
    .finally(() => {
      isLoading.value = false;
    });
};

useKeyboardEvents(keyboardEvents);

useEmitter(CMD_REOPEN_CONVERSATION, onCmdOpenConversation);
useEmitter(CMD_RESOLVE_CONVERSATION, onCmdResolveConversation);
</script>

<template>
  <div class="relative flex items-center justify-end resolve-actions">
    <!-- <div
      class="rounded-lg shadow outline-1 outline flex-shrink-0"
      :class="!showOpenButton ? 'outline-n-container' : 'outline-transparent'"
    >
      <Button
        v-if="isOpen"
        :label="t('CONVERSATION.HEADER.RESOLVE_ACTION')"
        size="sm"
        color="slate"
        no-animation
        class="ltr:rounded-r-none rtl:rounded-l-none !outline-0"
        :is-loading="isLoading"
        @click="onCmdResolveConversation"
      />
      <Button
        v-else-if="isResolved"
        :label="t('CONVERSATION.HEADER.REOPEN_ACTION')"
        size="sm"
        color="slate"
        no-animation
        class="ltr:rounded-r-none rtl:rounded-l-none !outline-0"
        :is-loading="isLoading"
        @click="onCmdOpenConversation"
      />
      <Button
        v-else-if="showOpenButton"
        :label="t('CONVERSATION.HEADER.OPEN_ACTION')"
        size="sm"
        color="slate"
        no-animation
        :is-loading="isLoading"
        @click="onCmdOpenConversation"
      />
      <Button
        v-if="showAdditionalActions"
        ref="arrowDownButtonRef"
        icon="i-lucide-chevron-down"
        :disabled="isLoading"
        size="sm"
        no-animation
        class="ltr:rounded-l-none rtl:rounded-r-none !outline-0"
        color="slate"
        trailing-icon
        @click="openDropdown"
      />
  </div> -->
    <div class="relative flex-shrink-0">
      <div
        class="rounded-xl shadow outline-1 outline flex-shrink-0 outline-n-container"
      >
        <Button
          v-if="!assignee"
          :label="t('CONVERSATION.ASSIGN_TO_HUMAN')"
          size="sm"
          color="slate"
          no-animation
          class="!outline-0 rounded-xl"
          :is-loading="isLoading"
          @click="openAgentDropdown"
        />
        <Button
          v-else
          :label="t('CONVERSATION.ASSIGNMENT.UNASSIGN')"
          size="sm"
          color="slate"
          no-animation
          class="!outline-0 rounded-xl"
          :is-loading="isLoading"
          @click="onUnassign"
        />
      </div>
      <div
        v-if="showAgentDropdown"
        v-on-clickaway="closeAgentDropdown"
        class="border rounded-lg shadow-lg border-n-strong dark:border-n-strong box-content p-2 w-[14rem] z-10 bg-n-alpha-3 backdrop-blur-[100px] absolute top-full mt-0.5 end-0"
      >
        <div class="flex items-center justify-between mb-1">
          <h4 class="m-0 text-sm text-n-slate-11">{{ t('CONVERSATION.ASSIGNMENT.SELECT_AGENT') }}</h4>
          <Button ghost slate xs icon="i-lucide-x" @click="closeAgentDropdown" />
        </div>
        <MultiselectDropdownItems
          :options="agentsList"
          :selected-items="assignee ? [assignee] : []"
          :has-thumbnail="true"
          :input-placeholder="t('CONVERSATION.ASSIGNMENT.SELECT_AGENT')"
          :no-search-result="t('CONVERSATION.CARD_CONTEXT_MENU.AGENTS_LOADING')"
          @select="onSelectAgent"
        />
      </div>
    </div>
    <div
      v-if="showActionsDropdown"
      v-on-clickaway="closeDropdown"
      class="border rounded-lg shadow-lg border-n-strong dark:border-n-strong box-content p-2 w-fit z-10 bg-n-alpha-3 backdrop-blur-[100px] absolute block left-auto top-full mt-0.5 start-0 xl:start-auto xl:end-0 max-w-[12.5rem] min-w-[9.75rem] [&_ul>li]:mb-0"
    >
      <WootDropdownMenu class="mb-0">
        <WootDropdownItem v-if="!isPending">
          <Button
            :label="t('CONVERSATION.RESOLVE_DROPDOWN.SNOOZE_UNTIL')"
            ghost
            slate
            sm
            start
            icon="i-lucide-alarm-clock-minus"
            class="w-full"
            @click="() => openSnoozeModal()"
          />
        </WootDropdownItem>
        <!-- <WootDropdownItem v-if="!isPending">
          <Button
            :label="t('CONVERSATION.RESOLVE_DROPDOWN.MARK_PENDING')"
            ghost
            slate
            sm
            start
            icon="i-lucide-circle-dot-dashed"
            class="w-full"
            @click="() => toggleStatus(wootConstants.STATUS_TYPE.PENDING)"
          />
        </WootDropdownItem> -->
      </WootDropdownMenu>
    </div>
  </div>
</template>
