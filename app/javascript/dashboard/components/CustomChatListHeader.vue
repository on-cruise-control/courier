<script setup>
import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { formatNumber } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';

import ConversationBasicFilter from './widgets/conversation/ConversationBasicFilter.vue';
import SwitchLayout from 'dashboard/routes/dashboard/conversation/search/SwitchLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import {
  DropdownContainer,
  DropdownBody,
  DropdownSection,
  DropdownItem,
} from 'next/dropdown-menu/base';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  pageTitle: { type: String, required: true },
  hasAppliedFilters: { type: Boolean, required: true },
  hasActiveFolders: { type: Boolean, required: true },
  activeStatus: { type: String, required: true },
  isOnExpandedLayout: { type: Boolean, required: true },
  conversationStats: { type: Object, required: true },
  isListLoading: { type: Boolean, required: true },
});

const emit = defineEmits([
  'addFolders',
  'deleteFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
]);

const { uiSettings, updateUISettings } = useUISettings();
const { t } = useI18n();
const { accountId, currentAccount } = useAccount();
const currentUser = useMapGetter('getCurrentUser');

const sortedAccounts = computed(() => {
  return [...(currentUser.value?.accounts || [])].sort((a, b) =>
    a.name.localeCompare(b.name)
  );
});

const onChangeAccount = newId => {
  window.location.href = `/app/accounts/${newId}/dashboard`;
};

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});

const allCount = computed(() => props.conversationStats?.allCount || 0);
const formattedAllCount = computed(() => formatNumber(allCount.value));

const toggleConversationLayout = () => {
  const { LAYOUT_TYPES } = wootConstants;
  const {
    conversation_display_type: conversationDisplayType = LAYOUT_TYPES.CONDENSED,
  } = uiSettings.value;
  const newViewType =
    conversationDisplayType === LAYOUT_TYPES.CONDENSED
      ? LAYOUT_TYPES.EXPANDED
      : LAYOUT_TYPES.CONDENSED;
  updateUISettings({
    conversation_display_type: newViewType,
    previously_used_conversation_display_type: newViewType,
  });
};

const statusText = computed(() => {
  if (Array.isArray(props.activeStatus)) {
    return props.activeStatus
      .map(status => t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${status}.TEXT`))
      .join(' , ');
  }
  return t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${props.activeStatus}.TEXT`);
});
</script>

<template>
  <div
    class="flex flex-col bg-transparent dark:bg-[#111112] transition-all border-b border-slate-50 dark:border-white/5"
    :class="{
      'border-b border-n-strong': hasAppliedFiltersOrActiveFolders,
    }"
  >
    <!-- Search bar row -->
    <div class="flex items-center gap-2 px-3 pt-3 pb-2">
      <div style="width: 30%">
        <DropdownContainer>
          <template #trigger="{ toggle, isOpen }">
            <button
              class="flex items-center justify-between gap-1 w-full px-2 py-2 rounded-lg bg-n-alpha-3 dark:bg-white/8 border border-n-weak hover:border-n-slate-6 dark:hover:border-white/20 transition-colors text-sm text-n-slate-11 min-w-0"
              :class="isOpen && 'border-n-slate-6 dark:border-white/20'"
              @click="toggle"
            >
              <span class="truncate min-w-0 flex-1 text-left text-xs leading-5">{{ currentAccount.name }}</span>
              <span class="i-lucide-chevrons-up-down size-3.5 flex-shrink-0 text-n-slate-10" />
            </button>
          </template>
          <DropdownBody class="min-w-80 z-50 shadow-2xl border-none rounded-lg outline-none">
            <DropdownSection :title="$t('SIDEBAR_ITEMS.SWITCH_ACCOUNT')">
              <DropdownItem
                v-for="account in sortedAccounts"
                :key="account.id"
                class="cursor-pointer"
                @click="onChangeAccount(account.id)"
              >
                <template #label>
                  <div class="flex items-center gap-3 text-left min-w-0 w-full">
                    <span class="text-n-slate-12 font-medium truncate flex-grow" :title="account.name">{{ account.name }}</span>
                    <div class="flex-shrink-0 w-px h-3 bg-n-strong" />
                    <span class="text-n-slate-11 text-xs capitalize whitespace-nowrap">
                      {{ account.custom_role_id ? account.custom_role?.name : account.role }}
                    </span>
                  </div>
                  <Icon
                    v-show="account.id === accountId"
                    icon="i-lucide-check"
                    class="text-n-teal-11 size-5 ml-2 flex-shrink-0"
                  />
                </template>
              </DropdownItem>
            </DropdownSection>
          </DropdownBody>
        </DropdownContainer>
      </div>
      <router-link
        :to="{ name: 'search' }"
        class="flex items-center gap-2 px-3 py-2 rounded-lg bg-n-alpha-3 dark:bg-white/5 border border-n-weak hover:border-n-slate-6 dark:hover:border-white/20 transition-colors group"
        style="width: 70%"
      >
        <span class="i-lucide-search size-4 text-n-slate-10 group-hover:text-n-slate-11 flex-shrink-0" />
        <span class="text-sm text-n-slate-10 group-hover:text-n-slate-11 truncate">
          {{ $t('CHAT_LIST.SEARCH.INPUT') }}
        </span>
      </router-link>
    </div>
    <div class="flex items-center justify-between gap-1 px-2 sm:px-4 h-12">
    <div class="flex items-center min-w-0 gap-1 sm:gap-2">
      <h1
        class="text-base sm:text-lg 2xl:text-[20px] font-bold tracking-tight text-slate-800 dark:text-slate-100 truncate"
        :title="pageTitle"
      >
        {{ pageTitle }}
      </h1>
      <span
        v-if="
          allCount > 0 && hasAppliedFiltersOrActiveFolders && !isListLoading
        "
        class="px-1.5 py-0.5 my-0.5 mx-0.5 rounded-md capitalize bg-n-slate-3 text-[10px] text-n-slate-12 shrink-0"
        :title="allCount"
      >
        {{ formattedAllCount }}
      </span>
      <span
        v-if="!hasAppliedFiltersOrActiveFolders"
        class="px-2 py-0.5 ml-0.5 rounded-full bg-slate-100 dark:bg-white/5 text-slate-600 dark:text-slate-400 font-medium text-[10px] shrink-0 border border-slate-200/50 dark:border-white/5 truncate max-w-[80px] sm:max-w-[120px]"
      >
        {{ statusText }}
      </span>
    </div>
    <div class="flex items-center gap-1.5">
      <template v-if="hasAppliedFilters && !hasActiveFolders">
        <div class="relative">
          <NextButton
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')"
            icon="i-lucide-save"
            slate
            xs
            faded
            class="!rounded-full hover:bg-slate-100 dark:hover:bg-white/5"
            @click="emit('addFolders')"
          />
          <div
            id="saveFilterTeleportTarget"
            class="absolute z-[200] mt-2"
          />
        </div>
        <NextButton
          v-tooltip.top-end="$t('FILTER.CLEAR_BUTTON_LABEL')"
          icon="i-lucide-circle-x"
          ruby
          faded
          xs
          class="!rounded-full"
          @click="emit('resetFilters')"
        />
      </template>
      <template v-if="hasActiveFolders">
        <div class="relative">
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')"
            icon="i-lucide-pen-line"
            slate
            xs
            faded
            class="!rounded-full"
            @click="emit('filtersModal')"
          />
          <div
            id="conversationFilterTeleportTarget"
            class="absolute z-[200] mt-2"
          />
        </div>
        <NextButton
          id="toggleConversationFilterButton"
          v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')"
          icon="i-lucide-trash-2"
          ruby
          xs
          faded
          class="!rounded-full"
          @click="emit('deleteFolders')"
        />
      </template>
      <div v-else class="relative">
        <NextButton
          id="toggleConversationFilterButton"
          v-tooltip.right="$t('FILTER.TOOLTIP_LABEL')"
          icon="i-lucide-filter"
          slate
          xs
          faded
          class="!rounded-full hover:bg-slate-100 dark:hover:bg-white/5 shadow-sm"
          @click="emit('filtersModal')"
        />
        <div
          id="conversationFilterTeleportTarget"
          class="absolute z-[200] mt-2"
        />
      </div>
      <ConversationBasicFilter
        v-if="!hasAppliedFiltersOrActiveFolders"
        :is-on-expanded-layout="isOnExpandedLayout"
        @change-filter="onBasicFilterChange"
      />
      <SwitchLayout
        :is-on-expanded-layout="isOnExpandedLayout"
        @toggle="toggleConversationLayout"
      />
    </div>
    </div>
  </div>
</template>

