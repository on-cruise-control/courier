<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useEventListener } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
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
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
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

const emit = defineEmits([
  'openKeyShortcutModal',
  'closeMobileSidebar',
  'activeGroupChange',
]);

const { t } = useI18n();
const store = useStore();
const { accountId, accountScopedRoute } = useAccount();
const notificationsMeta = useMapGetter('notifications/getMeta');

const { shouldShow } = usePolicy();
const router = useRouter();
const route = useRoute();

const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const hasConversationUnreadCounts = computed(() =>
  isFeatureEnabledonAccount.value(
    accountId.value,
    FEATURE_FLAGS.CONVERSATION_UNREAD_COUNTS
  )
);

const allUnreadCount = useMapGetter(
  'conversationUnreadCounts/getAllUnreadCount'
);
const mentionsUnreadCount = useMapGetter(
  'conversationUnreadCounts/getMentionsUnreadCount'
);
const participatingUnreadCount = useMapGetter(
  'conversationUnreadCounts/getParticipatingUnreadCount'
);
const unattendedUnreadCount = useMapGetter(
  'conversationUnreadCounts/getUnattendedUnreadCount'
);
const getInboxUnreadCount = useMapGetter(
  'conversationUnreadCounts/getInboxUnreadCount'
);
const getTeamUnreadCount = useMapGetter(
  'conversationUnreadCounts/getTeamUnreadCount'
);
const getLabelUnreadCount = useMapGetter(
  'conversationUnreadCounts/getLabelUnreadCount'
);
const getFolderUnreadCount = useMapGetter(
  'conversationUnreadCounts/getFolderUnreadCount'
);

const formatUnreadCount = count => {
  if (count > 99) return '99+';
  if (count > 0) return `${count}`;
  return null;
};

useSidebarKeyboardShortcuts(() => emit('openKeyShortcutModal'));

const findRouteByName = name => {
  return router.getRoutes().find(r => r.name === name);
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
const conversationCustomViews = useMapGetter(
  'customViews/getConversationCustomViews'
);

onMounted(() => {
  store.dispatch('labels/get');
  store.dispatch('inboxes/get');
  store.dispatch('notifications/unReadCount');
  store.dispatch('teams/get');
  store.dispatch('attributes/get');
  store.dispatch('customViews/get', 'conversation');
  store.dispatch('customViews/get', 'contact');
  if (hasConversationUnreadCounts.value) {
    store.dispatch('conversationUnreadCounts/get');
  }
});

const hasUnreadNotifications = computed(
  () => (notificationsMeta.value?.unreadCount || 0) > 0
);

const unreadNotificationsLabel = computed(() => {
  const count = notificationsMeta.value?.unreadCount || 0;
  return count > 99 ? '99+' : `${count}`;
});

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

  // Check explicit activeOn list first (handles detail pages like inbox_conversation)
  if (child.activeOn?.includes(currentRouteName)) return true;

  const targetRouteName = child.to.name;
  const targetParams = child.to.params || {};
  const targetNavigationPath = targetParams.navigationPath;

  if (currentRouteName === targetRouteName) {
    if (targetNavigationPath) {
      return route.params?.navigationPath === targetNavigationPath;
    }
    // Compare all non-accountId params to distinguish items sharing the same route name
    const relevantKeys = Object.keys(targetParams).filter(
      k => k !== 'accountId'
    );
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
  const targetPath =
    typeof child.to === 'string' ? child.to : router.resolve(child.to).href;

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
        {
          type: 'link',
          label: t('SIDEBAR.ALL_CONVERSATIONS'),
          icon: 'i-lucide-message-square',
          to: accountScopedRoute('home'),
          activeOn: ['inbox_conversation'],
          unreadCount: formatUnreadCount(allUnreadCount.value),
        },
        {
          type: 'link',
          label: t('SIDEBAR.MENTIONED_CONVERSATIONS'),
          icon: 'i-lucide-at-sign',
          to: accountScopedRoute('conversation_mentions'),
          activeOn: ['conversation_through_mentions'],
          unreadCount: formatUnreadCount(mentionsUnreadCount.value),
        },
        {
          type: 'link',
          label: t('SIDEBAR.PARTICIPATING_CONVERSATIONS'),
          icon: 'i-lucide-message-square-text',
          to: accountScopedRoute('conversation_participating'),
          activeOn: ['conversation_through_participating'],
          unreadCount: formatUnreadCount(participatingUnreadCount.value),
        },
        {
          type: 'link',
          label: t('SIDEBAR.UNATTENDED_CONVERSATIONS'),
          icon: 'i-lucide-clock',
          to: accountScopedRoute('conversation_unattended'),
          activeOn: ['conversation_through_unattended'],
          unreadCount: formatUnreadCount(unattendedUnreadCount.value),
        },
        {
          type: 'link',
          label: t('SIDEBAR.SPAM'),
          icon: 'i-lucide-octagon-alert',
          to: accountScopedRoute('conversation_spam'),
          activeOn: ['conversation_through_spam'],
        },
        {
          type: 'header',
          label: t('SIDEBAR.CUSTOM_VIEWS_FOLDER'),
          icon: 'i-lucide-folder',
        },
        ...conversationCustomViews.value.map(view => ({
          type: 'link',
          label: view.name,
          icon: 'i-lucide-folder',
          to: accountScopedRoute('folder_conversations', { id: view.id }),
          unreadCount: formatUnreadCount(getFolderUnreadCount.value(view.id)),
        })),
        { type: 'header', label: t('SIDEBAR.TEAMS'), icon: 'i-lucide-users' },
        ...teams.value.map(team => ({
          type: 'link',
          label: team.name,
          icon: 'i-lucide-users',
          to: accountScopedRoute('team_conversations', { teamId: team.id }),
          unreadCount: formatUnreadCount(getTeamUnreadCount.value(team.id)),
        })),
        {
          type: 'header',
          label: t('SIDEBAR.CHANNELS'),
          icon: 'i-lucide-mailbox',
        },
        ...inboxes.value.map(inbox => ({
          type: 'link',
          label: inbox.name,
          icon: getInboxIconByType(
            inbox.channel_type || inbox.channelType,
            inbox.medium
          ),
          to: accountScopedRoute('inbox_dashboard', { inbox_id: inbox.id }),
          reauthorizationRequired: inbox.reauthorization_required,
          unreadCount: formatUnreadCount(getInboxUnreadCount.value(inbox.id)),
        })),
        { type: 'header', label: t('SIDEBAR.LABELS'), icon: 'i-lucide-tag' },
        ...labels.value.map(label => ({
          type: 'link',
          label: label.title,
          color: label.color,
          to: accountScopedRoute('label_conversations', { label: label.title }),
          unreadCount: formatUnreadCount(
            getLabelUnreadCount.value(label.title)
          ),
        })),
      ],
    },
    {
      name: 'Contacts',
      label: t('SIDEBAR.CONTACTS'),
      icon: 'i-lucide-users-round',
      children: [
        {
          type: 'link',
          label: t('SIDEBAR.ALL_CONTACTS'),
          icon: 'i-lucide-users',
          to: accountScopedRoute('contacts_dashboard_index'),
          activeOn: ['contacts_edit', 'contact_profile_page'],
        },
        {
          type: 'link',
          label: t('SIDEBAR.ACTIVE'),
          icon: 'i-lucide-user-check',
          to: accountScopedRoute('contacts_dashboard_active'),
        },
        {
          type: 'header',
          label: t('SIDEBAR.CUSTOM_VIEWS_SEGMENTS'),
          icon: 'i-lucide-group',
        },
        ...contactCustomViews.value.map(view => ({
          type: 'link',
          label: view.name,
          icon: 'i-lucide-group',
          to: accountScopedRoute('contacts_dashboard_segments_index', {
            segmentId: view.id,
          }),
        })),
      ],
    },
    {
      name: 'Companies',
      label: t('SIDEBAR.COMPANIES'),
      icon: 'i-lucide-briefcase',
      children: [
        {
          type: 'link',
          label: t('SIDEBAR.ALL_COMPANIES'),
          icon: 'i-lucide-building',
          to: accountScopedRoute('companies_dashboard_index'),
        },
      ],
    },
    {
      name: 'Reports',
      label: t('SIDEBAR.REPORTS'),
      icon: 'i-lucide-bar-chart-3',
      children: [
        {
          type: 'link',
          label: t('SIDEBAR.REPORTS_OVERVIEW'),
          icon: 'i-lucide-chart-pie',
          to: accountScopedRoute('account_overview_reports'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.REPORTS_CONVERSATION'),
          icon: 'i-lucide-message-square-dashed',
          to: accountScopedRoute('conversation_reports'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.REPORTS_BOOKINGS'),
          icon: 'i-lucide-calendar',
          to: accountScopedRoute('bookings_reports'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.REPORTS_HANDOFF'),
          icon: 'i-lucide-handshake',
          to: accountScopedRoute('handoff_reports'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.TWILIO_USAGES'),
          icon: 'i-lucide-phone',
          to: accountScopedRoute('twilio_reports'),
        },
      ],
    },
    {
      name: 'Campaigns',
      label: t('SIDEBAR.CAMPAIGNS'),
      icon: 'i-lucide-send-horizontal',
      children: [
        {
          type: 'link',
          label: t('SIDEBAR.LIVE_CHAT'),
          icon: 'i-lucide-message-square',
          to: accountScopedRoute('campaigns_livechat_index'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.SMS'),
          icon: 'i-lucide-message-square',
          to: accountScopedRoute('campaigns_sms_index'),
        },
        {
          type: 'link',
          label: t('SIDEBAR.WHATSAPP'),
          icon: 'i-lucide-message-square-more',
          to: accountScopedRoute('campaigns_whatsapp_index'),
        },
      ],
    },
    {
      name: 'AI Assist',
      label: t('SIDEBAR.CAPTAIN'),
      icon: 'i-lucide-sparkles',
      children: [
        {
          type: 'link',
          label: t('SIDEBAR.CAPTAIN_RESPONSES'),
          icon: 'i-lucide-message-circle-question',
          to: accountScopedRoute('captain_assistants_index', {
            navigationPath: 'captain_assistants_responses_index',
          }),
        },
        {
          type: 'link',
          label: t('SIDEBAR.CAPTAIN_DOCUMENTS'),
          icon: 'i-lucide-file-text',
          to: accountScopedRoute('captain_assistants_index', {
            navigationPath: 'captain_assistants_documents_index',
          }),
        },
        {
          type: 'link',
          label: t('SIDEBAR.CAPTAIN_SCENARIOS'),
          icon: 'i-lucide-list-checks',
          to: accountScopedRoute('captain_assistants_index', {
            navigationPath: 'captain_assistants_scenarios_index',
          }),
        },
        {
          type: 'link',
          label: t('SIDEBAR.CAPTAIN_PLAYGROUND'),
          icon: 'i-lucide-flask-conical',
          to: accountScopedRoute('captain_assistants_index', {
            navigationPath: 'captain_assistants_playground_index',
          }),
        },
        {
          type: 'link',
          label: t('SIDEBAR.CAPTAIN_INBOXES'),
          icon: 'i-lucide-inbox',
          to: accountScopedRoute('captain_assistants_index', {
            navigationPath: 'captain_assistants_inboxes_index',
          }),
        },
        {
          type: 'link',
          label: t('SIDEBAR.CAPTAIN_TOOLS'),
          icon: 'i-lucide-wrench',
          to: accountScopedRoute('captain_assistants_index', {
            navigationPath: 'captain_tools_index',
          }),
        },
        {
          type: 'link',
          label: t('SIDEBAR.CAPTAIN_SETTINGS'),
          icon: 'i-lucide-settings',
          to: accountScopedRoute('captain_assistants_index', {
            navigationPath: 'captain_assistants_settings_index',
          }),
        },
      ],
    },
    {
      name: 'Contests',
      label: t('SIDEBAR.CONTESTS'),
      icon: 'i-lucide-trophy',
      to: accountScopedRoute('contests_index'),
      activeOn: ['contests_customers'],
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
        {
          type: 'link',
          label: t('SIDEBAR.HELP_CENTER.ARTICLES'),
          icon: 'i-lucide-file-text',
          to: accountScopedRoute('portals_index', {
            navigationPath: 'portals_articles_index',
          }),
          activeOn: [
            'portals_articles_new',
            'portals_articles_edit',
            'portals_new',
          ],
        },
        {
          type: 'link',
          label: t('SIDEBAR.HELP_CENTER.CATEGORIES'),
          icon: 'i-lucide-boxes',
          to: accountScopedRoute('portals_index', {
            navigationPath: 'portals_categories_index',
          }),
          activeOn: [
            'portals_categories_articles_index',
            'portals_categories_articles_new',
            'portals_categories_articles_edit',
          ],
        },
        {
          type: 'link',
          label: t('SIDEBAR.HELP_CENTER.LOCALES'),
          icon: 'i-lucide-languages',
          to: accountScopedRoute('portals_index', {
            navigationPath: 'portals_locales_index',
          }),
        },
        {
          type: 'link',
          label: t('SIDEBAR.HELP_CENTER.SETTINGS'),
          icon: 'i-lucide-settings',
          to: accountScopedRoute('portals_index', {
            navigationPath: 'portals_settings_index',
          }),
        },
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
          activeOn: [
            'settings_teams_new',
            'settings_teams_finish',
            'settings_teams_add_agents',
            'settings_teams_edit',
            'settings_teams_edit_members',
            'settings_teams_edit_finish',
          ],
        },
        {
          type: 'link',
          label: t('SIDEBAR.AGENT_ASSIGNMENT'),
          icon: 'i-lucide-user-cog',
          to: accountScopedRoute('assignment_policy_index'),
          activeOn: [
            'agent_assignment_policy_index',
            'agent_assignment_policy_create',
            'agent_assignment_policy_edit',
            'agent_capacity_policy_index',
            'agent_capacity_policy_create',
            'agent_capacity_policy_edit',
          ],
        },
        {
          type: 'link',
          label: t('SIDEBAR.INBOXES'),
          icon: 'i-lucide-inbox',
          to: accountScopedRoute('settings_inbox_list'),
          activeOn: [
            'settings_inbox_new',
            'settings_inbox_finish',
            'settings_inboxes_page_channel',
            'settings_inboxes_add_agents',
            'settings_inbox_show',
          ],
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
          activeOn: ['macros_edit', 'macros_new'],
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
          activeOn: [
            'settings_integrations_dashboard_apps',
            'settings_integrations_webhook',
            'settings_integrations_slack',
            'settings_integrations_linear',
            'settings_integrations_notion',
            'settings_integrations_shopify',
            'settings_applications_integration',
          ],
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
          label: t('SIDEBAR.CONVERSATION_WORKFLOW'),
          icon: 'i-lucide-git-branch',
          to: accountScopedRoute('conversation_workflow_index'),
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

  return items
    .map(item => {
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
    })
    .filter(item => {
      if (item.children) return item.children.some(c => c.type === 'link');
      return isAllowed(item.to);
    });
});

const bottomItems = computed(() => {
  const items = [];

  return items
    .map(item => {
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
    })
    .filter(item => {
      if (item.children) return item.children.some(c => c.type === 'link');
      return isAllowed(item.to);
    });
});

const hasBottomItems = computed(() => bottomItems.value.length > 0);

const activeGroup = ref(null);
const activeChildren = ref([]);
const expandedGroup = ref(null);

watch(activeGroup, groupName => {
  emit('activeGroupChange', groupName);
});

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
    if (defaultChild?.to) router.push(defaultChild.to);
  } else if (item.to) {
    router.push(item.to);
    expandedGroup.value = null;
  }

  if (props.isSmallScreen) emit('closeMobileSidebar');
};

const onChildClick = () => {
  activeGroup.value = null;
  activeChildren.value = [];
  if (props.isSmallScreen) emit('closeMobileSidebar');
};

const onCollapsedGroupClick = item => {
  const defaultChild = item.children?.find(child => child.type === 'link');
  if (defaultChild?.to) {
    router.push(defaultChild.to);
  }
  // Close flyout, just show the beak button
  activeGroup.value = null;
  activeChildren.value = [];
};

// Sidebar resize (main icon sidebar)
const { uiSettings, updateUISettings } = useUISettings();

const SIDEBAR_MIN_WIDTH = 60;
const SIDEBAR_DEFAULT_WIDTH = 60;
const SIDEBAR_COLLAPSED_THRESHOLD = 140;
const SIDEBAR_MAX_WIDTH = 280;

const sidebarWidth = ref(
  uiSettings.value.custom_sidebar_width || SIDEBAR_DEFAULT_WIDTH
);
const isCollapsed = computed(
  () => sidebarWidth.value < SIDEBAR_COLLAPSED_THRESHOLD
);

// Brand text scales linearly from 14px (at collapsed threshold) to 20px (at max width)
const brandTextSize = computed(() => {
  const progress =
    (sidebarWidth.value - SIDEBAR_COLLAPSED_THRESHOLD) /
    (SIDEBAR_MAX_WIDTH - SIDEBAR_COLLAPSED_THRESHOLD);
  const size = Math.round(14 + Math.max(0, Math.min(1, progress)) * 6);
  return `${size}px`;
});

// When sidebar expands: close flyout
watch(isCollapsed, nowCollapsed => {
  if (!nowCollapsed) {
    activeGroup.value = null;
    activeChildren.value = [];
  }
});

// Expanded sidebar accordion
const resolveExpandedGroup = () => {
  const activeItem = menuItems.value.find(
    item =>
      item.children &&
      item.children.some(child => child.type === 'link' && isChildActive(child))
  );
  return activeItem?.name ?? null;
};

// Re-resolve when route OR menu data changes (menu loads async: inboxes, labels, etc.)
// Only update when a matching group is found; navigating to a detail page (e.g. a
// conversation) returns null — in that case keep the current group open.
watch(
  [route, menuItems],
  () => {
    const resolved = resolveExpandedGroup();
    if (resolved !== null) {
      expandedGroup.value = resolved;
    }
  },
  { immediate: true }
);

const toggleExpandedGroup = item => {
  const isAlreadyExpanded = expandedGroup.value === item.name;
  const hasActiveChild = isGroupActive(item);

  // Mirror Chatwoot: navigate to first child only when the group is not
  // already open AND there is no currently-active child inside it.
  // Prevents redirecting away from the page the user is on.
  if (!isAlreadyExpanded && !hasActiveChild) {
    const firstChild = item.children?.find(c => c.type === 'link');
    if (firstChild?.to) router.push(firstChild.to);
  }

  expandedGroup.value = isAlreadyExpanded ? null : item.name;

  if (props.isSmallScreen) emit('closeMobileSidebar');
};

const isResizing = ref(false);
const resizeStartX = ref(0);
const resizeStartWidth = ref(0);

const getClientX = event =>
  event.touches ? event.touches[0].clientX : event.clientX;

const onResizeStart = event => {
  isResizing.value = true;
  resizeStartX.value = getClientX(event);
  resizeStartWidth.value = sidebarWidth.value;
  Object.assign(document.body.style, {
    cursor: 'col-resize',
    userSelect: 'none',
  });
  event.preventDefault();
};

const onResizeMove = event => {
  if (!isResizing.value) return;
  const delta = getClientX(event) - resizeStartX.value;
  sidebarWidth.value = Math.max(
    SIDEBAR_MIN_WIDTH,
    Math.min(SIDEBAR_MAX_WIDTH, resizeStartWidth.value + delta)
  );
};

const onResizeEnd = () => {
  if (!isResizing.value) return;
  isResizing.value = false;
  Object.assign(document.body.style, { cursor: '', userSelect: '' });
  if (sidebarWidth.value < SIDEBAR_COLLAPSED_THRESHOLD) {
    sidebarWidth.value = SIDEBAR_DEFAULT_WIDTH;
    updateUISettings({ custom_sidebar_width: SIDEBAR_DEFAULT_WIDTH });
  } else {
    updateUISettings({ custom_sidebar_width: Math.round(sidebarWidth.value) });
  }
};

const toggleSidebarCollapse = () => {
  if (isCollapsed.value) {
    sidebarWidth.value = 200;
    updateUISettings({ custom_sidebar_width: 200 });
  } else {
    sidebarWidth.value = SIDEBAR_DEFAULT_WIDTH;
    updateUISettings({ custom_sidebar_width: SIDEBAR_DEFAULT_WIDTH });
  }
};

useEventListener(document, 'mousemove', onResizeMove);
useEventListener(document, 'mouseup', onResizeEnd);
useEventListener(document, 'touchmove', onResizeMove, { passive: false });
useEventListener(document, 'touchend', onResizeEnd);
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
      class="fixed inset-0 bg-black/40 z-[-1]"
      @click="emit('closeMobileSidebar')"
    />

    <aside
      class="custom-sidebar flex flex-col h-full items-start py-4 z-50 flex-shrink-0 border-r border-black/10 shadow-lg relative"
      :class="{
        'transition-[width] duration-200': !isResizing,
        'is-collapsed': isCollapsed,
      }"
      :style="{ width: sidebarWidth + 'px', minWidth: sidebarWidth + 'px' }"
    >
      <!-- Fixed Blue Background -->
      <div class="absolute inset-y-0 inset-x-0 z-[-1] bg-[#182933]" />

      <div
        class="mb-2 flex py-1 pl-2 pr-3 w-full items-center"
        :class="isCollapsed ? 'justify-center' : ''"
      >
        <div class="flex items-center gap-2.5 min-w-0">
          <Logo class="size-10 text-white flex-shrink-0" />
          <span
            v-if="!isCollapsed"
            class="text-white font-bold tracking-tight truncate transition-[font-size] duration-200"
            :style="{ fontSize: brandTextSize }"
            >{{ t('SIDEBAR.BRAND_NAME') }}</span
          >
        </div>
      </div>

      <!-- Expanded: compose button beside the expand/collapse toggle -->
      <div
        v-if="!isCollapsed"
        class="flex items-center justify-between gap-2 mb-2 px-3 w-full"
      >
        <ComposeConversation @close="onComposeClose">
          <template #trigger="{ toggle }">
            <button
              class="size-8 rounded-xl bg-white/15 flex items-center justify-center text-white hover:bg-white/25 transition-all cursor-pointer flex-shrink-0"
              @click="onComposeOpen(toggle)"
            >
              <div class="i-lucide-pen-line size-4 flex-shrink-0" />
            </button>
          </template>
        </ComposeConversation>
        <button
          v-tooltip="{ content: t('SIDEBAR.COLLAPSE'), placement: 'right' }"
          class="size-8 !p-0 rounded-xl bg-white/15 flex items-center justify-center text-white hover:bg-white/25 transition-all cursor-pointer flex-shrink-0"
          @click="toggleSidebarCollapse"
        >
          <i class="i-lucide-chevrons-left size-5 text-white" />
        </button>
      </div>

      <!-- Collapsed only: expand toggle on top, compose button below -->
      <div
        v-if="isCollapsed"
        class="flex flex-col gap-2 mb-2 px-2 w-full items-center"
      >
        <button
          v-tooltip="{ content: t('SIDEBAR.EXPAND'), placement: 'right' }"
          class="size-8 !p-0 !pl-0.5 rounded-xl bg-white/15 flex items-center justify-center text-white hover:bg-white/25 transition-all cursor-pointer flex-shrink-0"
          @click="toggleSidebarCollapse"
        >
          <i class="i-lucide-chevrons-right size-5 text-white" />
        </button>
        <ComposeConversation @close="onComposeClose">
          <template #trigger="{ toggle }">
            <button
              class="size-10 rounded-xl bg-white/15 flex items-center justify-center text-white hover:bg-white/25 transition-all cursor-pointer flex-shrink-0"
              @click="onComposeOpen(toggle)"
            >
              <div class="i-lucide-pen-line size-5 flex-shrink-0" />
            </button>
          </template>
        </ComposeConversation>
      </div>

      <!-- ── COLLAPSED: icon-only nav with flyout on click ── -->
      <nav
        v-if="isCollapsed"
        class="flex flex-col gap-2 flex-grow items-center overflow-y-auto no-scrollbar py-2 w-full"
      >
        <template v-for="item in menuItems" :key="item.name">
          <!-- Group item -->
          <div v-if="item.children" class="flex flex-col items-center w-full">
            <button
              v-tooltip="{ content: item.label, placement: 'right' }"
              class="sidebar-item w-9 h-9 rounded-xl hover:bg-white/10 transition-all cursor-pointer flex items-center justify-center p-2 group/icon"
              :class="{
                'bg-white/35 shadow-inner':
                  activeGroup === item.name || isGroupActive(item),
              }"
              @click="onCollapsedGroupClick(item)"
            >
              <div
                class="size-5 text-white group-hover/icon:scale-110 transition-transform"
                :class="item.icon"
              />
            </button>
            <div
              v-if="isGroupActive(item)"
              class="w-[40px] h-[24px] flex items-center justify-center bg-[#182933] rounded-b-xl shadow-[0_4px_10px_rgba(0,0,0,0.1)] cursor-pointer z-40"
              @click.stop="toggleGroup(item)"
            >
              <div
                class="flex items-center justify-center size-5 rounded-full transition-all"
                :class="{
                  'bg-white/35 shadow-inner':
                    activeGroup === item.name || isGroupActive(item),
                }"
              >
                <i
                  class="i-lucide-chevron-down size-3.5 text-white transition-transform duration-200"
                  :class="{ 'rotate-180': activeGroup === item.name }"
                />
              </div>
            </div>
          </div>
          <!-- Link item -->
          <div v-else class="flex justify-center w-full">
            <router-link
              v-tooltip="{ content: item.label, placement: 'right' }"
              :to="item.to"
              class="sidebar-item relative w-9 h-9 rounded-xl hover:bg-white/10 transition-all flex items-center justify-center p-2 group"
              active-class="bg-white/35"
              @click="navigateItem(item)"
            >
              <div
                class="size-5 text-white group-hover:scale-110 transition-transform"
                :class="item.icon"
              />
              <span
                v-if="item.name === 'Inbox' && hasUnreadNotifications"
                class="absolute -top-1 -right-1 min-w-[16px] h-4 px-1 rounded-full text-[10px] leading-4 text-white bg-n-teal-9 text-center"
                >{{ unreadNotificationsLabel }}</span
              >
            </router-link>
          </div>
        </template>
      </nav>

      <!-- ── EXPANDED: accordion navigation (one section open at a time) ── -->
      <nav
        v-else
        class="flex flex-col flex-grow overflow-y-auto no-scrollbar py-1 w-full px-2"
      >
        <template v-for="item in menuItems" :key="item.name">
          <!-- Group with children: clickable accordion toggle -->
          <template v-if="item.children">
            <button
              class="flex items-center gap-2 w-full px-2 py-1.5 rounded-lg hover:bg-white/10 transition-all cursor-pointer"
              :class="{ 'bg-white/15': isGroupActive(item) }"
              @click="toggleExpandedGroup(item)"
            >
              <div
                class="size-4 text-white/80 flex-shrink-0"
                :class="item.icon"
              />
              <span
                class="text-white/90 text-[13px] font-medium truncate flex-1 text-left"
                >{{ item.label }}</span
              >
              <div
                class="i-lucide-chevron-right size-3.5 text-white/40 flex-shrink-0 transition-transform duration-200"
                :class="{ 'rotate-90': expandedGroup === item.name }"
              />
            </button>

            <!-- Children container: shown when expanded OR when a child is active.
                 Mirrors Chatwoot's v-show="isExpanded || hasActiveChild".
                 Each child is individually shown/hidden below using the same pattern
                 so only the active child is visible when the group is collapsed. -->
            <div
              v-show="expandedGroup === item.name || isGroupActive(item)"
              class="mt-0.5 mb-1 ml-3 pl-2 border-l border-white/10 flex flex-col gap-0.5"
            >
              <template
                v-for="child in item.children"
                :key="
                  (child.label || '') + String(child.to?.name || child.to || '')
                "
              >
                <!-- Sub-section headers only show when fully expanded -->
                <div
                  v-if="child.type === 'header'"
                  v-show="expandedGroup === item.name"
                  class="px-2 pt-3 pb-1 text-[9px] font-bold uppercase tracking-widest text-white/30 select-none"
                >
                  {{ child.label }}
                </div>

                <!-- Each child link: always visible when expanded;
                     only the active child is visible when the group is collapsed. -->
                <router-link
                  v-else
                  v-show="expandedGroup === item.name || isChildActive(child)"
                  :to="child.to"
                  class="flex items-center gap-2 px-2 py-1.5 rounded-lg hover:bg-white/10 transition-all"
                  :class="{ 'bg-white/20': isChildActive(child) }"
                  @click="onChildClick"
                >
                  <div
                    v-if="child.color"
                    class="size-2 rounded-full flex-shrink-0"
                    :style="{ backgroundColor: child.color }"
                  />
                  <Icon
                    v-else-if="child.icon"
                    :icon="child.icon"
                    class="size-3.5 text-white/60 flex-shrink-0"
                  />
                  <div
                    v-else
                    class="size-1.5 rounded-full bg-white/50 flex-shrink-0"
                  />
                  <span
                    class="text-white/85 text-[13px] font-medium truncate flex-1"
                    >{{ child.label }}</span
                  >
                  <span
                    v-if="child.unreadCount"
                    class="min-w-[16px] h-4 px-1 rounded-full text-[10px] leading-4 text-white bg-n-teal-9 text-center flex-shrink-0"
                  >
                    {{ child.unreadCount }}
                  </span>
                  <div
                    v-if="child.reauthorizationRequired"
                    v-tooltip.top-end="$t('SIDEBAR.REAUTHORIZE')"
                    class="grid place-content-center size-4 bg-n-ruby-5/60 rounded-full flex-shrink-0"
                  >
                    <Icon icon="i-woot-alert" class="size-2.5 text-n-ruby-9" />
                  </div>
                </router-link>
              </template>
            </div>
          </template>

          <!-- Standalone link (no children) -->
          <router-link
            v-else
            :to="item.to"
            class="flex items-center gap-2 px-2 py-1.5 rounded-lg hover:bg-white/10 transition-all"
            active-class="bg-white/20"
            @click="navigateItem(item)"
          >
            <div class="size-4 text-white flex-shrink-0" :class="item.icon" />
            <span
              class="text-white/90 text-[13px] font-medium truncate flex-1"
              >{{ item.label }}</span
            >
            <span
              v-if="item.name === 'Inbox' && hasUnreadNotifications"
              class="min-w-[16px] h-4 px-1 rounded-full text-[10px] leading-4 text-white bg-n-teal-9 text-center ml-auto"
              >{{ unreadNotificationsLabel }}</span
            >
          </router-link>
        </template>
      </nav>

      <!-- Bottom Items -->
      <template v-if="hasBottomItems">
        <div class="w-8 h-px bg-white/10 my-3 flex-shrink-0 mx-auto" />
        <nav
          class="mb-4 w-full px-2"
          :class="
            isCollapsed
              ? 'flex flex-col items-center gap-2'
              : 'flex flex-col gap-0.5'
          "
        >
          <template v-for="item in bottomItems" :key="item.name">
            <!-- Collapsed: icon buttons -->
            <template v-if="isCollapsed">
              <div
                v-if="item.children"
                class="relative flex justify-center w-full"
              >
                <button
                  v-tooltip="{ content: item.label, placement: 'right' }"
                  class="sidebar-item w-9 h-9 rounded-xl hover:bg-white/10 transition-all cursor-pointer flex items-center justify-center p-2 group/icon"
                  :class="{
                    'bg-white/35 shadow-inner': activeGroup === item.name,
                  }"
                  @click="toggleGroup(item)"
                >
                  <div
                    class="size-5 text-white group-hover/icon:scale-110 transition-transform"
                    :class="item.icon"
                  />
                </button>
                <div
                  class="absolute top-full left-1/2 -translate-x-1/2 w-[40px] h-[24px] flex items-center justify-center bg-[#182933] rounded-b-xl shadow-[0_4px_10px_rgba(0,0,0,0.1)] transition-all duration-200 z-[60] cursor-pointer"
                  :class="{
                    'opacity-100 translate-y-0':
                      activeGroup === item.name || isGroupActive(item),
                    'opacity-0 pointer-events-none -translate-y-1':
                      activeGroup !== item.name && !isGroupActive(item),
                  }"
                  @click.stop="toggleGroup(item)"
                >
                  <i
                    class="i-lucide-chevron-right size-[16px] text-white transition-transform duration-300"
                    :class="{ 'rotate-180': activeGroup === item.name }"
                  />
                </div>
              </div>
              <div v-else class="flex justify-center w-full">
                <router-link
                  v-tooltip="{ content: item.label, placement: 'right' }"
                  :to="item.to"
                  class="sidebar-item w-9 h-9 rounded-xl hover:bg-white/10 transition-all flex items-center justify-center p-2 group"
                  active-class="bg-white/35"
                  @click="navigateItem(item)"
                >
                  <div
                    class="size-5 text-white group-hover:scale-110 transition-transform"
                    :class="item.icon"
                  />
                </router-link>
              </div>
            </template>

            <!-- Expanded: full-width rows -->
            <template v-else>
              <div v-if="item.children">
                <div
                  class="px-2 pt-3 pb-1 text-[10px] font-bold uppercase tracking-wider text-white/40 select-none"
                >
                  {{ item.label }}
                </div>
                <template
                  v-for="child in item.children"
                  :key="
                    (child.label || '') +
                    String(child.to?.name || child.to || '')
                  "
                >
                  <div
                    v-if="child.type === 'header'"
                    class="px-2 pt-3 pb-1 text-[9px] font-bold uppercase tracking-widest text-white/30 select-none"
                  >
                    {{ child.label }}
                  </div>
                  <router-link
                    v-else
                    :to="child.to"
                    class="flex items-center gap-2 px-2 py-1.5 rounded-lg hover:bg-white/10 transition-all"
                    :class="{ 'bg-white/20': isChildActive(child) }"
                    @click="onChildClick"
                  >
                    <Icon
                      v-if="child.icon"
                      :icon="child.icon"
                      class="size-3.5 text-white/60 flex-shrink-0"
                    />
                    <span
                      class="text-white/85 text-[13px] font-medium truncate flex-1"
                      >{{ child.label }}</span
                    >
                  </router-link>
                </template>
              </div>
              <router-link
                v-else
                :to="item.to"
                class="flex items-center gap-2 px-2 py-1.5 rounded-lg hover:bg-white/10 transition-all"
                active-class="bg-white/20"
                @click="navigateItem(item)"
              >
                <div
                  class="size-4 text-white flex-shrink-0"
                  :class="item.icon"
                />
                <span
                  class="text-white/90 text-[13px] font-medium truncate flex-1"
                  >{{ item.label }}</span
                >
              </router-link>
            </template>
          </template>
        </nav>
      </template>

      <!-- Profile -->
      <div
        class="sidebar-profile px-2 pt-2 border-t border-white/10 w-full"
        :class="isCollapsed ? 'flex justify-center' : ''"
      >
        <SidebarProfileMenu
          class="bg-transparent border-none !p-0"
          @open-key-shortcut-modal="emit('openKeyShortcutModal')"
        />
      </div>

      <!-- Mobile close button -->
      <button
        v-if="isSmallScreen"
        class="mt-3 ml-3 mb-2 size-10 rounded-full bg-white/10 flex items-center justify-center text-white hover:bg-white/20 transition-all cursor-pointer border border-white/20"
        @click="emit('closeMobileSidebar')"
      >
        <div class="i-lucide-x size-5" />
      </button>

      <!-- Resize handle (desktop only) — must be last so z-index stacks above content -->
      <div
        class="hidden md:block absolute top-0 h-full w-2 cursor-col-resize z-40 right-0 group"
        @mousedown="onResizeStart"
        @touchstart="onResizeStart"
        @dblclick="toggleSidebarCollapse"
      >
        <div
          class="absolute top-0 h-full w-px right-0 bg-transparent group-hover:bg-white/40 transition-colors"
          :class="{ 'bg-white/60': isResizing }"
        />
      </div>
    </aside>

    <!-- Flyout Menu for Child Items (Push Layout) -->
    <transition
      enter-active-class="transition-opacity ease-out duration-200"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity ease-in duration-150"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="activeGroup && isCollapsed"
        class="custom-flyout h-full backdrop-blur-2xl z-40 border-r py-10 flex flex-col flex-shrink-0 w-64 min-w-64"
      >
        <div class="px-6 mb-6">
          <div
            class="flyout-header-text text-[10px] font-black uppercase tracking-[0.2em] whitespace-nowrap"
          >
            {{ activeGroup }}
          </div>
        </div>

        <div
          class="flex-grow overflow-y-auto no-scrollbar px-3 flex flex-col gap-1"
        >
          <template v-for="child in activeChildren" :key="child.label">
            <div
              v-if="child.type === 'header'"
              class="flyout-sub-header mt-4 mb-2 px-3 text-[9px] font-bold uppercase tracking-widest whitespace-nowrap opacity-60"
            >
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
              <span
                class="text-[13px] font-semibold transition-colors truncate flex-1"
                >{{ child.label }}</span
              >
              <span
                v-if="child.unreadCount"
                class="min-w-[18px] h-[18px] px-1 rounded-full text-[10px] leading-[18px] text-white bg-n-teal-9 text-center flex-shrink-0"
              >
                {{ child.unreadCount }}
              </span>
              <div
                v-if="child.reauthorizationRequired"
                v-tooltip.top-end="$t('SIDEBAR.REAUTHORIZE')"
                class="grid place-content-center size-5 bg-n-ruby-5/60 rounded-full flex-shrink-0"
              >
                <Icon icon="i-woot-alert" class="size-3 text-n-ruby-9" />
              </div>
            </router-link>
          </template>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped lang="scss">
.custom-sidebar {
  background-color: #1b5cb6;

  // Override name/email text colors in the trigger button only.
  // Scoped to `button > .min-w-0` so the dropdown body (DropdownItem uses
  // the same slate tokens on a light background) is never affected.
  .sidebar-profile {
    :deep(button > .min-w-0 .text-n-slate-12) {
      color: rgba(255, 255, 255, 0.95) !important;
    }

    :deep(button > .min-w-0 .text-n-slate-11) {
      color: rgba(255, 255, 255, 0.6) !important;
    }
  }
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
