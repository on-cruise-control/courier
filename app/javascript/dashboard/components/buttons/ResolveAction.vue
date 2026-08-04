<script setup>
import { ref, computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAgentsList } from 'dashboard/composables/useAgentsList';

import MultiselectDropdownItems from 'shared/components/ui/MultiselectDropdownItems.vue';

import ButtonGroup from 'dashboard/components-next/buttonGroup/ButtonGroup.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();

const isLoading = ref(false);

const [showAgentDropdown, toggleAgentDropdown] = useToggle();
const closeAgentDropdown = () => toggleAgentDropdown(false);
const openAgentDropdown = () => toggleAgentDropdown(true);

const { agentsList } = useAgentsList();

const currentChat = computed(() => getters.getSelectedChat.value);

const assignee = computed(() => currentChat.value?.meta?.assignee);
const selectedAgent = computed(() => (assignee.value ? [assignee.value] : []));

const onUnassignAgent = async () => {
  isLoading.value = true;
  try {
    await store.dispatch('assignAgent', {
      conversationId: currentChat.value.id,
      agentId: 0,
    });
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
  } finally {
    isLoading.value = false;
  }
};

const onSelectAgent = async agent => {
  closeAgentDropdown();
  isLoading.value = true;
  const agentId = agent ? agent.id : 0;

  try {
    await store.dispatch('assignAgent', {
      conversationId: currentChat.value.id,
      agentId,
    });
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <div class="flex relative justify-end items-center resolve-actions">
    <ButtonGroup
      class="flex-shrink-0 rounded-lg shadow outline-1 outline outline-n-container"
    >
      <Button
        v-if="assignee"
        :label="t('CONVERSATION.ASSIGNMENT.UNASSIGN')"
        size="sm"
        color="slate"
        no-animation
        class="!outline-0"
        :is-loading="isLoading"
        @click="onUnassignAgent"
      />
      <Button
        v-else
        :label="t('CONVERSATION.ASSIGN_TO_HUMAN')"
        size="sm"
        color="slate"
        no-animation
        class="!outline-0"
        :is-loading="isLoading"
        @click="openAgentDropdown"
      />
    </ButtonGroup>
    <div
      v-if="showAgentDropdown"
      v-on-clickaway="closeAgentDropdown"
      class="border rounded-lg shadow-lg border-n-strong dark:border-n-strong box-content p-2 w-56 z-10 bg-n-alpha-3 backdrop-blur-[100px] absolute block left-auto top-full mt-0.5 start-0 xl:start-auto xl:end-0"
    >
      <div class="flex items-center justify-between gap-2 mb-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CONVERSATION.ASSIGNMENT.SELECT_AGENT') }}
        </span>
        <Button
          icon="i-lucide-x"
          size="xs"
          color="slate"
          variant="ghost"
          @click="closeAgentDropdown"
        />
      </div>
      <MultiselectDropdownItems
        :options="agentsList"
        :selected-items="selectedAgent"
        :input-placeholder="t('CONVERSATION.ASSIGNMENT.SELECT_AGENT')"
        @select="onSelectAgent"
      />
    </div>
  </div>
</template>
