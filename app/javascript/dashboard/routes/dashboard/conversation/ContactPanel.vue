<script setup>
import { computed, watch, onMounted, ref } from 'vue';
import {
  useMapGetter,
  useFunctionGetter,
  useStore,
} from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';
import CustomAccordionItem from 'dashboard/components/Accordion/CustomAccordionItem.vue';
import SidebarActionsHeader from 'dashboard/components-next/SidebarActionsHeader.vue';
import CustomSidebarActionsHeader from 'dashboard/components-next/CustomSidebarActionsHeader.vue';
import ContactInfo from './contact/ContactInfo.vue';
import ContactConversations from './ContactConversations.vue';
import ConversationAction from './ConversationAction.vue';
import ConversationParticipant from './ConversationParticipant.vue';
import CustomContactInfo from './contact/CustomContactInfo.vue';
import CustomConversationAction from './CustomConversationAction.vue';

import ContactNotes from './contact/ContactNotes.vue';
import ConversationInfo from './ConversationInfo.vue';
import CustomAttributes from './customAttributes/CustomAttributes.vue';
import SharedFiles from './SharedFiles.vue';
import Draggable from 'vuedraggable';
import MacrosList from './Macros/List.vue';
import ShopifyOrdersList from 'dashboard/components/widgets/conversation/ShopifyOrdersList.vue';
import LinearIssuesList from 'dashboard/components/widgets/conversation/linear/IssuesList.vue';
import LinearSetupCTA from 'dashboard/components/widgets/conversation/linear/LinearSetupCTA.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  inboxId: {
    type: Number,
    default: undefined,
  },
});

const {
  updateUISettings,
  isContactSidebarItemOpen,
  conversationSidebarItemsOrder,
  toggleSidebarUIState,
} = useUISettings();

const ACCORDION_KEYS = [
  'is_conv_actions_open',
  'is_conv_participants_open',
  'is_conv_details_open',
  'is_contact_attributes_open',
  'is_previous_conv_open',
  'is_macro_open',
  'is_linear_issues_open',
  'is_shopify_orders_open',
  'is_contact_notes_open',
  'is_shared_files_open',
];

const toggleAccordionItem = key => {
  const isOpen = isContactSidebarItemOpen(key);
  const updates = Object.fromEntries(ACCORDION_KEYS.map(k => [k, false]));
  if (!isOpen) updates[key] = true;
  updateUISettings(updates);
};

const dragging = ref(false);
const conversationSidebarItems = ref([]);

const currentAccountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter('accounts/isFeatureEnabledonAccount');

const isCustomUIEnabled = computed(() =>
  isFeatureEnabledonAccount.value(currentAccountId.value, FEATURE_FLAGS.CUSTOM_UI)
);

const AccordionComponent = computed(() =>
  isCustomUIEnabled.value ? CustomAccordionItem : AccordionItem
);

const SidebarHeaderComponent = computed(() =>
  isCustomUIEnabled.value ? CustomSidebarActionsHeader : SidebarActionsHeader
);

const shopifyIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'shopify'
);

const isShopifyFeatureEnabled = computed(
  () => shopifyIntegration.value.enabled
);

const isLinearFeatureEnabled = computed(() =>
  isFeatureEnabledonAccount.value(currentAccountId.value, FEATURE_FLAGS.LINEAR)
);

const linearIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'linear'
);


const isLinearClientIdConfigured = computed(() => {
  return !!linearIntegration.value?.id;
});

const isLinearConnected = computed(
  () => linearIntegration.value?.enabled || false
);

const store = useStore();
const currentChat = useMapGetter('getSelectedChat');
const conversationId = computed(() => props.conversationId);
const conversationMetadataGetter = useMapGetter(
  'conversationMetadata/getConversationMetadata'
);
const currentConversationMetaData = computed(() =>
  conversationMetadataGetter.value(conversationId.value)
);
const conversationAdditionalAttributes = computed(
  () => currentConversationMetaData.value.additional_attributes || {}
);

const channelType = computed(() => currentChat.value.meta?.channel);

const contactGetter = useMapGetter('contacts/getContact');
const contactId = computed(() => currentChat.value.meta?.sender?.id);
const contact = computed(() => contactGetter.value(contactId.value));
const contactAdditionalAttributes = computed(
  () => contact.value.additional_attributes || {}
);

const getContactDetails = () => {
  if (contactId.value) {
    store.dispatch('contacts/show', { id: contactId.value });
  }
};


watch(contactId, (newContactId, prevContactId) => {
  if (newContactId && newContactId !== prevContactId) {
    getContactDetails();
  }
});

const onDragEnd = () => {
  dragging.value = false;
  updateUISettings({
    conversation_sidebar_items_order: conversationSidebarItems.value,
  });
};

const closeContactPanel = () => {
  updateUISettings({
    is_contact_sidebar_open: false,
    is_copilot_panel_open: false,
  });
};

onMounted(() => {
  conversationSidebarItems.value = conversationSidebarItemsOrder.value;
  getContactDetails();
  store.dispatch('attributes/get', 0);
  // Load integrations to ensure linear integration state is available
  store.dispatch('integrations/get', 'linear');
});
</script>

<template>
  <div class="w-full">
    <component
      :is="SidebarHeaderComponent"
      v-if="!isCustomUIEnabled"
      :title="$t('CONVERSATION.SIDEBAR.CONTACT')"
      @close="closeContactPanel"
    />
    <CustomContactInfo
      v-if="isCustomUIEnabled"
      :contact="contact"
      :channel-type="channelType"
      @panel-close="closeContactPanel"
    />
    <ContactInfo v-else :contact="contact" :channel-type="channelType" />
    <div class="px-3 pb-8 list-group">
      <Draggable
        :list="conversationSidebarItems"
        animation="200"
        ghost-class="ghost"
        handle=".drag-handle"
        item-key="name"
        class="flex flex-col gap-3"
        @start="dragging = true"
        @end="onDragEnd"
      >
        <template #item="{ element }">
          <div
            v-if="element.name === 'conversation_actions'"
            class="conversation--actions"
          >
            <component
              :is="AccordionComponent"
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_ACTIONS')"
              :is-open="isContactSidebarItemOpen('is_conv_actions_open')"
              @toggle="() => toggleAccordionItem('is_conv_actions_open')"
            >
              <CustomConversationAction
                v-if="isCustomUIEnabled"
                :conversation-id="conversationId"
                :inbox-id="inboxId"
              />
              <ConversationAction
                v-else
                :conversation-id="conversationId"
                :inbox-id="inboxId"
              />
            </component>
          </div>
          <div
            v-else-if="element.name === 'conversation_participants'"
            class="conversation--actions"
          >
            <component
              :is="AccordionComponent"
              :title="$t('CONVERSATION_PARTICIPANTS.SIDEBAR_TITLE')"
              :is-open="isContactSidebarItemOpen('is_conv_participants_open')"
              @toggle="() => toggleAccordionItem('is_conv_participants_open')"
            >
              <ConversationParticipant
                :conversation-id="conversationId"
                :inbox-id="inboxId"
              />
            </component>
          </div>
          <div v-else-if="element.name === 'conversation_info'">
            <component
              :is="AccordionComponent"
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_INFO')"
              :is-open="isContactSidebarItemOpen('is_conv_details_open')"
              compact
              @toggle="() => toggleAccordionItem('is_conv_details_open')"
            >
              <ConversationInfo
                :conversation-attributes="conversationAdditionalAttributes"
                :contact-attributes="contactAdditionalAttributes"
              />
            </component>
          </div>
          <div v-else-if="element.name === 'contact_attributes'">
            <component
              :is="AccordionComponent"
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONTACT_ATTRIBUTES')"
              :is-open="isContactSidebarItemOpen('is_contact_attributes_open')"
              compact
              @toggle="() => toggleAccordionItem('is_contact_attributes_open')"
            >
              <CustomAttributes
                attribute-type="contact_attribute"
                attribute-from="conversation_contact_panel"
                :contact-id="contact.id"
                :empty-state-message="
                  $t('CONVERSATION_CUSTOM_ATTRIBUTES.NO_RECORDS_FOUND')
                "
              />
            </component>
          </div>
          <div v-else-if="element.name === 'previous_conversation'">
            <component
              :is="AccordionComponent"
              v-if="contact.id"
              :title="
                $t('CONVERSATION_SIDEBAR.ACCORDION.PREVIOUS_CONVERSATION')
              "
              :is-open="isContactSidebarItemOpen('is_previous_conv_open')"
              compact
              @toggle="() => toggleAccordionItem('is_previous_conv_open')"
            >
              <ContactConversations
                :contact-id="contact.id"
                :conversation-id="conversationId"
              />
            </component>
          </div>
          <woot-feature-toggle
            v-else-if="element.name === 'macros'"
            feature-key="macros"
          >
            <component
              :is="AccordionComponent"
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.MACROS')"
              :is-open="isContactSidebarItemOpen('is_macro_open')"
              compact
              @toggle="() => toggleAccordionItem('is_macro_open')"
            >
              <MacrosList :conversation-id="conversationId" />
            </component>
          </woot-feature-toggle>
          <div
            v-else-if="
              element.name === 'linear_issues' &&
              isLinearFeatureEnabled &&
              isLinearClientIdConfigured
            "
          >
            <component
              :is="AccordionComponent"
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.LINEAR_ISSUES')"
              :is-open="isContactSidebarItemOpen('is_linear_issues_open')"
              compact
              @toggle="() => toggleAccordionItem('is_linear_issues_open')"
            >
              <LinearSetupCTA v-if="!isLinearConnected" />
              <LinearIssuesList v-else :conversation-id="conversationId" />
            </component>
          </div>
          <div
            v-else-if="
              element.name === 'shopify_orders' && isShopifyFeatureEnabled
            "
          >
            <component
              :is="AccordionComponent"
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.SHOPIFY_ORDERS')"
              :is-open="isContactSidebarItemOpen('is_shopify_orders_open')"
              compact
              @toggle="() => toggleAccordionItem('is_shopify_orders_open')"
            >
              <ShopifyOrdersList :contact-id="contactId" />
            </component>
          </div>
          <div v-else-if="element.name === 'contact_notes'">
            <component
              :is="AccordionComponent"
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONTACT_NOTES')"
              :is-open="isContactSidebarItemOpen('is_contact_notes_open')"
              compact
              @toggle="() => toggleAccordionItem('is_contact_notes_open')"
            >
              <ContactNotes :contact-id="contactId" />
            </component>
          </div>
          <div v-else-if="element.name === 'shared_files'">
            <component
              :is="AccordionComponent"
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.SHARED_FILES')"
              :is-open="isContactSidebarItemOpen('is_shared_files_open')"
              compact
              @toggle="() => toggleAccordionItem('is_shared_files_open')"
            >
              <SharedFiles />
            </component>
          </div>
        </template>
      </Draggable>
    </div>
  </div>
</template>

<style lang="scss" scoped>
:deep(.contact--profile) {
  @apply pb-3 border-b border-solid border-n-weak;
}
</style>
