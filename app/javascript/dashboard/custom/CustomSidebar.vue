<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useRouter, useRoute } from 'vue-router';
import SidebarProfileMenu from '../components-next/sidebar/SidebarProfileMenu.vue';
import Logo from 'next/icon/Logo.vue';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { useSidebarKeyboardShortcuts } from 'dashboard/components-next/sidebar/useSidebarKeyboardShortcuts';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSection,
  DropdownItem,
} from 'next/dropdown-menu/base';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  isMobileSidebarOpen: {
    type: Boolean,
    default: false,
  },
  isSmallScreen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['openKeyShortcutModal', 'showCreateAccountModal', 'closeMobileSidebar']);

const { t } = useI18n();
const store = useStore();
const { accountId, currentAccount, accountScopedRoute } = useAccount();
const currentUser = useMapGetter('getCurrentUser');
const globalConfig = useMapGetter('globalConfig/get');
const userAccounts = useMapGetter('getUserAccounts');
const notificationsMeta = useMapGetter('notifications/getMeta');

const { shouldShow } = usePolicy();
const router = useRouter();
const route = useRoute();

useSidebarKeyboardShortcuts(() => emit('openKeyShortcutModal'));

const findRouteByName = name => {
  return router.getRoutes().find(route => route.name === name);
};

const isAllowed = to => {
  if (!to) return true;
  const resolved = router.resolve(to);
  if (!resolved || resolved.name === '404') return true;

  let meta = resolved.meta;
  if (to.params?.navigationPath) {
    const targetRoute = findRouteByName(to.params.navigationPath);
    meta = targetRoute?.meta || meta;
  }

  const permissions = meta?.permissions || [];
  const featureFlag = meta?.featureFlag || '';
  const installationType = meta?.installationTypes || [];

  return shouldShow(featureFlag, permissions, installationType);
};

// Dynamic data for sidebars
const inboxes = useMapGetter('inboxes/getInboxes');
const labels = useMapGetter('labels/getLabelsOnSidebar');
const teams = useMapGetter('teams/getMyTeams');
const contactCustomViews = useMapGetter('customViews/getContactCustomViews');
const conversationCustomViews = useMapGetter('customViews/getConversationCustomViews');

onMounted(() => {
  store.dispatch('labels/get');
  store.dispatch('inboxes/get');
  store.dispatch('notifications/unReadCount');
  store.dispatch('teams/get');
  store.dispatch('attributes/get');
  store.dispatch('customViews/get', 'conversation');
  store.dispatch('customViews/get', 'contact');
});

const showAccountSwitcher = computed(
  () => (userAccounts.value || []).length > 1 && currentAccount.value.name
);

const hasUnreadNotifications = computed(
  () => (notificationsMeta.value?.unreadCount || 0) > 0
);

const unreadNotificationsLabel = computed(() => {
  const count = notificationsMeta.value?.unreadCount || 0;
  return count > 99 ? '99+' : `${count}`;
});

const sortedCurrentUserAccounts = computed(() => {
  return [...(currentUser.value.accounts || [])].sort((a, b) =>
    a.name.localeCompare(b.name)
  );
});

const onChangeAccount = newId => {
  const accountUrl = `/app/accounts/${newId}/dashboard`;
  window.location.href = accountUrl;
};

const onComposeOpen = toggleFn => {
  toggleFn();
  emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, true);
};

const onComposeClose = () => {
  emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, false);
};

const isChildActive = child => {
  if (!child.to) return false;

  const currentRouteName = route.name;
  const targetRouteName = child.to.name;
  const targetParams = child.to.params || {};
  const targetNavigationPath = targetParams.navigationPath;

  if (currentRouteName === targetRouteName) {
    if (targetNavigationPath) {
      return route.params?.navigationPath === targetNavigationPath;
    }
    // Compare all non-accountId params to distinguish items sharing the same route name
    const relevantKeys = Object.keys(targetParams).filter(k => k !== 'accountId');
    if (relevantKeys.length > 0) {
      return relevantKeys.every(
        k => String(route.params[k]) === String(targetParams[k])
      );
    }
    return true;
  }

  if (targetNavigationPath && currentRouteName === targetNavigationPath) {
    return true;
  }

  const currentPath = route.path;
  const targetPath = typeof child.to === 'string' ? child.to : router.resolve(child.to).href;

  return currentPath === targetPath;
};

const isGroupActive = item => {
  if (item.to && isChildActive(item)) return true;
  if (item.children) {
    return item.children.some(child => isChildActive(child));
  }
  return false;
};

const menuItems = computed(() => {
  const items = [
    {
      name: 'Inbox',
      label: t('SIDEBAR.INBOX'),
      icon: 'i-lucide-inbox',
      to: accountScopedRoute('inbox_view'),
    },
    {
      name: 'Conversation',
      label: t('SIDEBAR.CONVERSATIONS'),
      icon: 'i-lucide-message-square-more',
      children: [
        { type: 'link', label: t('SIDEBAR.ALL_CONVERSATIONS'), icon: 'i-lucide-message-square', to: accountScopedRoute('home') },
        { type: 'link', label: t('SIDEBAR.MENTIONED_CONVERSATIONS'), icon: 'i-lucide-at-sign', to: accountScopedRoute('conversation_mentions') },
        { type: 'link', label: t('SIDEBAR.UNATTENDED_CONVERSATIONS'), icon: 'i-lucide-clock', to: accountScopedRoute('conversation_unattended') },
        { type: 'link', label: t('SIDEBAR.SPAM'), icon: 'i-lucide-octagon-alert', to: accountScopedRoute('conversation_spam') },
        { type: 'header', label: t('SIDEBAR.CUSTOM_VIEWS_FOLDER'), icon: 'i-lucide-folder' },
        ...conversationCustomViews.value.map(view => ({
          type: 'link',
          label: view.name,
          icon: 'i-lucide-folder',
          to: accountScopedRoute('folder_conversations', { id: view.id }),
        })),
        { type: 'header', label: t('SIDEBAR.TEAMS'), icon: 'i-lucide-users' },
        ...teams.value.map(team => ({
          type: 'link',
          label: team.name,
          icon: 'i-lucide-users',
          to: accountScopedRoute('team_conversations', { teamId: team.id }),
        })),
        { type: 'header', label: t('SIDEBAR.CHANNELS'), icon: 'i-lucide-mailbox' },
        ...inboxes.value.map(inbox => ({
          type: 'link',
          label: inbox.name,
          icon: getInboxIconByType(inbox.channel_type || inbox.channelType, inbox.medium),
          to: accountScopedRoute('inbox_dashboard', { inbox_id: inbox.id }),
        })),
        { type: 'header', label: t('SIDEBAR.LABELS'), icon: 'i-lucide-tag' },
        ...labels.value.map(label => ({
          type: 'link',
          label: label.title,
          color: label.color,
          to: accountScopedRoute('label_conversations', { label: label.title }),
        })),
      ],
    },
    {
      name: 'Contacts',
      label: t('SIDEBAR.CONTACTS'),
      icon: 'i-lucide-users-round',
      children: [
        { type: 'link', label: t('SIDEBAR.ALL_CONTACTS'), icon: 'i-lucide-users', to: accountScopedRoute('contacts_dashboard_index') },
        { type: 'link', label: t('SIDEBAR.ACTIVE'), icon: 'i-lucide-user-check', to: accountScopedRoute('contacts_dashboard_active') },
        { type: 'header', label: t('SIDEBAR.CUSTOM_VIEWS_SEGMENTS'), icon: 'i-lucide-group' },
        ...contactCustomViews.value.map(view => ({
          type: 'link',
          label: view.name,
          icon: 'i-lucide-group',
          to: accountScopedRoute('contacts_dashboard_segments_index', { segmentId: view.id }),
        })),
      ],
    },
    {
      name: 'Companies',
      label: t('SIDEBAR.COMPANIES'),
      icon: 'i-lucide-briefcase',
      children: [
        { type: 'link', label: t('SIDEBAR.ALL_COMPANIES'), icon: 'i-lucide-building', to: accountScopedRoute('companies_dashboard_index') },
      ],
    },
    {
      name: 'Reports',
      label: t('SIDEBAR.REPORTS'),
      icon: 'i-lucide-bar-chart-3',
      children: [
        { type: 'link', label: t('SIDEBAR.REPORTS_OVERVIEW'), icon: 'i-lucide-chart-pie', to: accountScopedRoute('account_overview_reports') },
        { type: 'link', label: t('SIDEBAR.REPORTS_CONVERSATION'), icon: 'i-lucide-message-square-dashed', to: accountScopedRoute('conversation_reports') },
        { type: 'link', label: t('SIDEBAR.REPORTS_BOOKINGS'), icon: 'i-lucide-calendar', to: accountScopedRoute('bookings_reports') },
        { type: 'link', label: t('SIDEBAR.REPORTS_HANDOFF'), icon: 'i-lucide-handshake', to: accountScopedRoute('handoff_reports') },
        { type: 'link', label: t('SIDEBAR.TWILIO_USAGES'), icon: 'i-lucide-phone', to: accountScopedRoute('twilio_reports') },
      ],
    },
    {
      name: 'Campaigns',
      label: t('SIDEBAR.CAMPAIGNS'),
      icon: 'i-lucide-send-horizontal',
      children: [
        { type: 'link', label: t('SIDEBAR.LIVE_CHAT'), icon: 'i-lucide-message-square', to: accountScopedRoute('campaigns_livechat_index') },
        { type: 'link', label: t('SIDEBAR.SMS'), icon: 'i-lucide-message-square', to: accountScopedRoute('campaigns_sms_index') },
        { type: 'link', label: t('SIDEBAR.WHATSAPP'), icon: 'i-lucide-message-square-more', to: accountScopedRoute('campaigns_whatsapp_index') },
      ],
    },
    {
      name: 'AI Assist',
      label: t('SIDEBAR.CAPTAIN'),
      icon: 'i-lucide-sparkles',
      to: accountScopedRoute('captain_assistants_index', {
        navigationPath: 'captain_assistants_responses_index',
      }),
    },
    {
      name: 'Contests',
      label: t('SIDEBAR.CONTESTS'),
      icon: 'i-lucide-trophy',
      to: accountScopedRoute('contests_index'),
    },
    {
      name: 'Bookings',
      label: t('BOOKINGS.HEADER'),
      icon: 'i-lucide-calendar-check',
      to: accountScopedRoute('bookings_index'),
      activeOn: ['bookings_index'],
    },
    {
      name: 'Portals',
      label: t('SIDEBAR.HELP_CENTER.TITLE'),
      icon: 'i-lucide-book-open-text',
      children: [
        { type: 'link', label: t('SIDEBAR.HELP_CENTER.ARTICLES'), icon: 'i-lucide-file-text', to: accountScopedRoute('portals_index', { navigationPath: 'portals_articles_index' }) },
        { type: 'link', label: t('SIDEBAR.HELP_CENTER.CATEGORIES'), icon: 'i-lucide-boxes', to: accountScopedRoute('portals_index', { navigationPath: 'portals_categories_index' }) },
        { type: 'link', label: t('SIDEBAR.HELP_CENTER.LOCALES'), icon: 'i-lucide-languages', to: accountScopedRoute('portals_index', { navigationPath: 'portals_locales_index' }) },
        { type: 'link', label: t('SIDEBAR.HELP_CENTER.SETTINGS'), icon: 'i-lucide-settings', to: accountScopedRoute('portals_index', { navigationPath: 'portals_settings_index' }) },
      ],
    },
    {
      name: 'Settings',
      label: t('SIDEBAR.SETTINGS'),
      icon: 'i-lucide-settings-2',
      children: [
        {
          type: 'link',
          label: t('SIDEBAR.ACCOUNT_SETTINGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('general_settings_index'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.AGENTS'),
          icon: 'i-lucide-square-user',
          to: accountScopedRoute('agent_list'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.TEAMS'),
          icon: 'i-lucide-users',
          to: accountScopedRoute('settings_teams_list'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.AGENT_ASSIGNMENT'),
          icon: 'i-lucide-user-cog',
          to: accountScopedRoute('assignment_policy_index'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.INBOXES'),
          icon: 'i-lucide-inbox',
          to: accountScopedRoute('settings_inbox_list'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.LABELS'),
          icon: 'i-lucide-tags',
          to: accountScopedRoute('labels_list'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.CUSTOM_ATTRIBUTES'),
          icon: 'i-lucide-code',
          to: accountScopedRoute('attributes_list'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.AUTOMATION'),
          icon: 'i-lucide-workflow',
          to: accountScopedRoute('automation_list'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.AGENT_BOTS'),
          icon: 'i-lucide-bot',
          to: accountScopedRoute('agent_bots'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.MACROS'),
          icon: 'i-lucide-toy-brick',
          to: accountScopedRoute('macros_wrapper'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.CANNED_RESPONSES'),
          icon: 'i-lucide-message-square-quote',
          to: accountScopedRoute('canned_list'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.INTEGRATIONS'),
          icon: 'i-lucide-blocks',
          to: accountScopedRoute('settings_applications'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.AUDIT_LOGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('auditlogs_list'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.CUSTOM_ROLES'),
          icon: 'i-lucide-shield-plus',
          to: accountScopedRoute('custom_roles_list'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.SLA'),
          icon: 'i-lucide-clock-alert',
          to: accountScopedRoute('sla_list'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.SECURITY'),
          icon: 'i-lucide-shield',
          to: accountScopedRoute('security_settings_index'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.BILLING'),
          icon: 'i-lucide-credit-card',
          to: accountScopedRoute('billing_settings_index'),
        },
      ],
    },
  ];

  return items.map(item => {
    if (!item.children) return item;
    
    const filteredChildren = [];
    let pendingHeader = null;
    
    item.children.forEach(child => {
      if (child.type === 'header') {
        pendingHeader = child;
      } else if (child.type === 'link') {
        if (isAllowed(child.to)) {
          if (pendingHeader) {
            filteredChildren.push(pendingHeader);
            pendingHeader = null;
          }
          filteredChildren.push(child);
        }
      }
    });

    return { ...item, children: filteredChildren };
  }).filter(item => {
    if (item.children) return item.children.some(c => c.type === 'link');
    return isAllowed(item.to);
  });
});

const bottomItems = computed(() => {
  const items = [];

  return items.map(item => {
    if (!item.children) return item;
    
    const filteredChildren = [];
    let pendingHeader = null;
    
    item.children.forEach(child => {
      if (child.type === 'header') {
        pendingHeader = child;
      } else if (child.type === 'link') {
        if (isAllowed(child.to)) {
          if (pendingHeader) {
            filteredChildren.push(pendingHeader);
            pendingHeader = null;
          }
          filteredChildren.push(child);
        }
      }
    });

    return { ...item, children: filteredChildren };
  }).filter(item => {
    if (item.children) return item.children.some(c => c.type === 'link');
    return isAllowed(item.to);
  });
});

const hasBottomItems = computed(() => bottomItems.value.length > 0);

const activeGroup = ref(null);
const activeChildren = ref([]);

const toggleGroup = item => {
  if (activeGroup.value === item.name) {
    activeGroup.value = null;
    activeChildren.value = [];
  } else {
    activeGroup.value = item.name;
    activeChildren.value = item.children || [];
  }
};

const navigateItem = item => {
  activeGroup.value = null;
  activeChildren.value = [];
  
  if (item.children) {
    const defaultChild = item.children.find(child => child.type === 'link');
    if (defaultChild?.to) {
      router.push(defaultChild.to);
    }
  } else if (item.to) {
    router.push(item.to);
  }
  
  if (isSmallScreen.value) {
    emit('closeMobileSidebar');
  }
};
const onChildClick = () => {
  activeGroup.value = null;
  activeChildren.value = [];
  if (isSmallScreen.value) {
    emit('closeMobileSidebar');
  }
};
</script>

<template>
  <!-- Normal: always show. Small screen: only show when open as a fixed overlay -->
  <div
    v-if="!isSmallScreen || isMobileSidebarOpen"
    class="flex h-full relative no-scrollbar flex-shrink-0"
    :class="isSmallScreen ? 'fixed inset-y-0 left-0 z-[200]' : ''"
  >
    <!-- Backdrop overlay for mobile - clicking closes sidebar -->
    <div
      v-if="isSmallScreen && isMobileSidebarOpen"
      class="fixed inset-0 bg-black/60 backdrop-blur-sm z-[-1]"
      @click="emit('closeMobileSidebar')"
    />

    <aside
      class="custom-sidebar flex flex-col h-full items-start py-4 z-50 flex-shrink-0 border-r border-black/10 shadow-lg relative"
      style="background-color: transparent; width: 5.625rem; min-width: 5.625rem; max-width: 5.625rem;"
    >
      <!-- Fixed Blue Background -->
      <div
        class="absolute inset-y-0 inset-x-0 z-[-1]"
        style="background-color: #182933;"
      />

      <div class="mb-6 w-16 flex justify-center py-1">
        <Logo class="size-10 text-white" />
      </div>

      <!-- Compose -->
      <div class="flex flex-col gap-2 mb-4 px-2 w-16">
        <ComposeConversation align-position="right" @close="onComposeClose">
          <template #trigger="{ toggle }">
            <button
              class="size-10 rounded-xl bg-white/15 flex items-center justify-center text-white hover:bg-white/25 transition-all cursor-pointer"
              @click="onComposeOpen(toggle)"
            >
              <div class="i-lucide-pen-line size-5" />
            </button>
          </template>
        </ComposeConversation>
      </div>

      <!-- Scrollable Nav Section -->
      <nav class="flex flex-col gap-3 flex-grow items-start overflow-y-auto w-[110px] no-scrollbar py-2">
        <template v-for="item in menuItems" :key="item.name">
          <div v-if="item.children" class="relative flex items-center justify-center group w-16">
            <button
              class="sidebar-item p-2 rounded-xl hover:bg-white/10 transition-all flex-shrink-0 w-9 h-9 flex items-center justify-center cursor-pointer group/icon"
              :class="{ 'bg-white/35 shadow-inner': activeGroup === item.name }"
              v-tooltip.right="item.label"
              @click="navigateItem(item)"
            >
              <div
                class="size-5 text-white group-hover/icon:scale-110 transition-transform"
                :class="item.icon"
              />
            </button>
            
            <!-- Beak Toggle (Fixed for Active Section) -->
            <div
              class="absolute left-full top-1/2 -translate-y-1/2 w-[24px] h-[40px] flex items-center justify-center bg-[#182933] rounded-r-xl shadow-[4px_0_10px_rgba(0,0,0,0.1)] transition-all duration-200 z-[10] cursor-pointer"
              :class="{
                'opacity-100 translate-x-0': activeGroup === item.name || isGroupActive(item),
                'opacity-0 -translate-x-1': activeGroup !== item.name && !isGroupActive(item)
              }"
              @click.stop="toggleGroup(item)"
            >
              <i
                class="i-lucide-chevron-right size-[16px] text-white transition-transform duration-300"
                :class="{ 'rotate-180': activeGroup === item.name }"
              />
            </div>
          </div>

          <div v-else class="w-16 flex justify-center">
            <router-link
              :to="item.to"
              class="sidebar-item relative p-2 rounded-xl hover:bg-white/10 transition-all flex-shrink-0 w-9 h-9 flex items-center justify-center group"
              active-class="bg-white/35"
              v-tooltip.right="item.label"
              @click="navigateItem(item)"
            >
              <div
                class="size-5 text-white group-hover:scale-110 transition-transform"
                :class="item.icon"
              />
              <span
                v-if="item.name === 'Inbox' && hasUnreadNotifications"
                class="absolute -top-1 -right-1 min-w-[16px] h-4 px-1 rounded-full text-[10px] leading-4 text-white bg-n-teal-9 text-center"
              >
                {{ unreadNotificationsLabel }}
              </span>
            </router-link>
          </div>
        </template>
      </nav>

      <template v-if="hasBottomItems">
        <div class="w-8 h-px bg-white/10 my-4 flex-shrink-0" />
        <nav class="flex flex-col gap-3 items-start w-[90px] px-0 mb-4">
          <template v-for="item in bottomItems" :key="item.name">
            <div v-if="item.children" class="relative flex items-center justify-center group w-16 px-0">
              <button
                class="sidebar-item p-2 rounded-xl hover:bg-white/10 transition-all flex-shrink-0 w-9 h-9 flex items-center justify-center cursor-pointer group/icon"
                :class="{ 'bg-white/35 shadow-inner': activeGroup === item.name }"
                v-tooltip.right="item.label"
                @click="navigateItem(item)"
              >
                <div
                  class="size-5 text-white group-hover/icon:scale-110 transition-transform"
                  :class="item.icon"
                />
              </button>
              
              <!-- Beak Toggle (Fixed for Active Section) -->
              <div
                class="absolute left-full top-1/2 -translate-y-1/2 w-[24px] h-[40px] flex items-center justify-center bg-[#182933] rounded-r-xl shadow-[4px_0_10px_rgba(0,0,0,0.1)] transition-all duration-200 z-[10] cursor-pointer"
                :class="{
                  'opacity-100 translate-x-0': activeGroup === item.name || isGroupActive(item),
                  'opacity-0 -translate-x-1': activeGroup !== item.name && !isGroupActive(item)
                }"
                @click.stop="toggleGroup(item)"
              >
                <i
                  class="i-lucide-chevron-right size-[16px] text-white transition-transform duration-300"
                  :class="{ 'rotate-180': activeGroup === item.name }"
                />
              </div>
            </div>
            <div v-else class="w-16 flex justify-center">
              <router-link
                :to="item.to"
                class="sidebar-item p-2 rounded-xl hover:bg-white/10 transition-all flex-shrink-0 w-9 h-9 flex items-center justify-center group"
                active-class="bg-white/35"
                v-tooltip.right="item.label"
                @click="navigateItem(item)"
              >
                <div
                  class="size-5 text-white group-hover:scale-110 transition-transform"
                  :class="item.icon"
                />
              </router-link>
            </div>
          </template>
        </nav>
      </template>

      <div class="px-0 pt-2 border-t border-white/10 w-16 flex justify-center">
        <SidebarProfileMenu
          class="bg-transparent border-none !p-0"
          @open-key-shortcut-modal="emit('openKeyShortcutModal')"
        />
      </div>

      <!-- Mobile close button -->
      <button
        v-if="isSmallScreen"
        class="mt-3 mx-auto mb-2 size-10 rounded-full bg-white/10 flex items-center justify-center text-white hover:bg-white/20 transition-all cursor-pointer border border-white/20"
        @click="emit('closeMobileSidebar')"
      >
        <div class="i-lucide-x size-5" />
      </button>
    </aside>

    <!-- Flyout Menu for Child Items (Push Layout) -->
    <transition
      enter-active-class="transition-all ease-out duration-300"
      enter-from-class="opacity-0 w-0"
      enter-to-class="opacity-100 w-64"
      leave-active-class="transition-all ease-in duration-200"
      leave-from-class="opacity-100 w-64"
      leave-to-class="opacity-0 w-0"
    >
      <div
        v-if="activeGroup"
        class="custom-flyout h-full w-64 backdrop-blur-2xl z-40 border-r py-10 flex flex-col overflow-hidden flex-shrink-0"
        style="min-width: 16rem; max-width: 16rem;"
      >
        <div class="px-6 mb-6">
          <div class="flyout-header-text text-[10px] font-black uppercase tracking-[0.2em] whitespace-nowrap">
            {{ activeGroup }}
          </div>
        </div>

        <div class="flex-grow overflow-y-auto no-scrollbar px-3 flex flex-col gap-1">
          <template v-for="child in activeChildren" :key="child.label">
            <div v-if="child.type === 'header'" class="flyout-sub-header mt-4 mb-2 px-3 text-[9px] font-bold uppercase tracking-widest whitespace-nowrap opacity-60">
              {{ child.label }}
            </div>
            <router-link
              v-else
              :to="child.to"
              class="flyout-link group flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all whitespace-nowrap"
              :class="{ active: isChildActive(child) }"
              @click="onChildClick"
            >
              <div 
                v-if="child.color" 
                class="size-2 rounded-full shadow-sm flex-shrink-0"
                :style="{ backgroundColor: child.color }"
              />
              <Icon
                v-else-if="child.icon"
                :icon="child.icon"
                class="size-[14px] flex-shrink-0 opacity-70 group-hover:opacity-100 transition-opacity"
              />
              <div 
                v-else
                class="flyout-link-indicator size-1.5 rounded-full transition-all flex-shrink-0" 
              />
              <span class="text-[13px] font-semibold transition-colors truncate">{{ child.label }}</span>
            </router-link>
          </template>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped lang="scss">
.custom-sidebar {
  width: 64px;
  background-color: #1b5cb6;
}
.sidebar-item {
  color: white;
  &.router-link-active:not(button) {
    background-color: rgba(255, 255, 255, 0.2);
  }
}
// Hide scrollbar but keep functionality
.no-scrollbar {
  scrollbar-width: none;
  -ms-overflow-style: none;
  &::-webkit-scrollbar {
    display: none;
  }
}
</style>
