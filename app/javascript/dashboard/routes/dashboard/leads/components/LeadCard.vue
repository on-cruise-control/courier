<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { messageTimestamp } from 'shared/helpers/timeHelper';
import { buildLeadAnswers } from '../leadAnswers';

const props = defineProps({
  lead: { type: Object, required: true },
  questions: { type: Array, default: () => [] },
  isExpanded: { type: Boolean, default: false },
  isStarting: { type: Boolean, default: false },
});

const emit = defineEmits(['toggle', 'start']);

const { t } = useI18n();
const router = useRouter();
const accountId = useMapGetter('getCurrentAccountId');

const STATUS_CLASSES = {
  sent: 'bg-n-teal-3 text-n-teal-11',
  partial: 'bg-n-amber-3 text-n-amber-11',
  needs_config: 'bg-n-amber-3 text-n-amber-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
};

const statusClass = computed(
  () =>
    STATUS_CLASSES[props.lead.outreach_status] || 'bg-n-alpha-2 text-n-slate-11'
);
const sentResults = computed(() =>
  props.lead.outreach.filter(
    result => result.status === 'sent' && result.conversation_id
  )
);
const problems = computed(() =>
  props.lead.outreach_status === 'sent'
    ? []
    : props.lead.outreach.filter(result =>
        ['failed', 'needs_config'].includes(result.status)
      )
);
const canStart = computed(
  () =>
    props.lead.outreach_status !== 'skipped' &&
    props.lead.outreach_status !== 'sent'
);
const startLabel = computed(() =>
  props.lead.outreach_status === 'pending'
    ? t('FACEBOOK_LEADS.OUTREACH.START')
    : t('FACEBOOK_LEADS.OUTREACH.RETRY')
);

const channelLabel = result =>
  [t(`FACEBOOK_LEADS.OUTREACH.CHANNELS.${result.channel}`), result.inbox_name]
    .filter(Boolean)
    .join(' · ');

const showConversations = ref(false);
const conversationMenuItems = computed(() =>
  sentResults.value.map(result => ({
    label: channelLabel(result),
    action: 'open',
    value: result.conversation_id,
    icon: 'i-lucide-message-square',
  }))
);

const openConversation = conversationId =>
  router.push(
    frontendURL(`accounts/${accountId.value}/conversations/${conversationId}`)
  );

const onConversationSelect = ({ value }) => {
  showConversations.value = false;
  openConversation(value);
};

const receivedAt = computed(() =>
  messageTimestamp(
    Math.floor(new Date(props.lead.lead_created_at).getTime() / 1000),
    'MMM dd, yyyy hh:mm a'
  )
);

const NAME_KEYS = ['full_name', 'first_name', 'last_name'];
// Contact details first in the card summary, then the form's other answers in order
const SUMMARY_PRIORITY = ['email', 'phone_number'];
const SUMMARY_LIMIT = 3;

const answers = computed(() => buildLeadAnswers(props.lead, props.questions));

// Forms without a name question fall back to their first answer as the title
const title = computed(
  () =>
    props.lead.name ||
    answers.value[0]?.value ||
    t('FACEBOOK_LEADS.CARD.UNKNOWN_NAME')
);

// Meta reports the platform as fb or ig
const PLATFORM_NAMES = { fb: 'Facebook', ig: 'Instagram' };

const adDetails = computed(() =>
  [
    {
      label: t('FACEBOOK_LEADS.CARD.PLATFORM'),
      value: PLATFORM_NAMES[props.lead.platform] || props.lead.platform,
    },
    { label: t('FACEBOOK_LEADS.CARD.AD'), value: props.lead.ad_name },
    { label: t('FACEBOOK_LEADS.CARD.ADSET'), value: props.lead.adset_name },
    {
      label: t('FACEBOOK_LEADS.CARD.CAMPAIGN'),
      value: props.lead.campaign_name,
    },
  ].filter(detail => detail.value)
);

const summary = computed(() => {
  const rest = answers.value.filter(
    answer => !NAME_KEYS.includes(answer.key) && answer.value !== title.value
  );
  const rank = answer => {
    const index = SUMMARY_PRIORITY.indexOf(answer.key);
    return index === -1 ? SUMMARY_PRIORITY.length : index;
  };
  return [...rest].sort((a, b) => rank(a) - rank(b)).slice(0, SUMMARY_LIMIT);
});
</script>

<template>
  <CardLayout layout="row">
    <div class="flex items-center justify-start flex-1 gap-4 min-w-0">
      <Avatar :name="title" :size="42" />
      <div class="flex flex-col gap-0.5 flex-1 min-w-0">
        <div class="flex flex-wrap items-center gap-x-4 gap-y-1">
          <span class="text-base font-medium truncate text-n-slate-12">
            {{ title }}
          </span>
          <span
            class="px-1.5 py-0.5 text-xs font-medium rounded-md"
            :class="statusClass"
          >
            {{ t(`FACEBOOK_LEADS.OUTREACH.STATUS.${lead.outreach_status}`) }}
          </span>
        </div>
        <div class="flex flex-wrap items-center justify-start gap-x-3 gap-y-1">
          <template v-for="answer in summary" :key="answer.key">
            <span
              class="text-sm truncate max-w-72 text-n-slate-11"
              :title="`${answer.label}: ${answer.value}`"
            >
              {{ answer.value }}
            </span>
            <div class="w-px h-3 bg-n-slate-6" />
          </template>
          <span class="text-sm truncate text-n-slate-11">
            {{ receivedAt }}
          </span>
          <div class="w-px h-3 bg-n-slate-6" />
          <Button
            :label="t('FACEBOOK_LEADS.CARD.VIEW_ANSWERS')"
            variant="link"
            size="xs"
            @click="emit('toggle')"
          />
        </div>
        <p
          v-if="problems.length"
          class="text-sm truncate text-n-ruby-11"
          :title="problems[0].error"
        >
          {{ problems[0].error }}
        </p>
      </div>
    </div>

    <div class="flex items-center gap-2" @click.stop>
      <Button
        v-if="sentResults.length === 1"
        :label="t('FACEBOOK_LEADS.OUTREACH.VIEW_CONVERSATION')"
        icon="i-lucide-message-square"
        variant="faded"
        color="slate"
        size="xs"
        @click="openConversation(sentResults[0].conversation_id)"
      />
      <div
        v-else-if="sentResults.length > 1"
        v-on-clickaway="() => (showConversations = false)"
        class="relative"
      >
        <Button
          :label="t('FACEBOOK_LEADS.OUTREACH.VIEW_CONVERSATION')"
          icon="i-lucide-chevron-down"
          trailing-icon
          variant="faded"
          color="slate"
          size="xs"
          @click="showConversations = !showConversations"
        />
        <DropdownMenu
          v-if="showConversations"
          :menu-items="conversationMenuItems"
          class="ltr:right-0 rtl:left-0 mt-1 w-52 top-full"
          @action="onConversationSelect"
        />
      </div>
      <Button
        v-if="canStart"
        :label="startLabel"
        size="xs"
        :is-loading="isStarting"
        @click="emit('start')"
      />
    </div>

    <Button
      icon="i-lucide-chevron-down"
      variant="ghost"
      color="slate"
      size="xs"
      :class="{ 'rotate-180': isExpanded }"
      @click="emit('toggle')"
    />

    <template #after>
      <div
        class="transition-all duration-500 ease-in-out grid overflow-hidden"
        :class="
          isExpanded
            ? 'grid-rows-[1fr] opacity-100'
            : 'grid-rows-[0fr] opacity-0'
        "
      >
        <div class="overflow-hidden">
          <div class="flex flex-col gap-6 p-6 border-t border-n-strong">
            <ul
              v-if="lead.outreach.length"
              class="flex flex-col gap-2 pb-4 border-b border-n-weak"
            >
              <li
                v-for="result in lead.outreach"
                :key="`${result.channel}-${result.inbox_id}`"
                class="flex flex-wrap items-center gap-2 text-sm"
              >
                <span class="font-medium text-n-slate-12">
                  {{ channelLabel(result) }}
                </span>
                <span v-if="result.address" class="text-n-slate-11">
                  {{ result.address }}
                </span>
                <span
                  v-if="result.status === 'sent' && result.conversation_id"
                  class="text-n-teal-11"
                >
                  {{ t('FACEBOOK_LEADS.OUTREACH.CONVERSATION_STARTED') }}
                </span>
                <span
                  v-else-if="result.status === 'sent'"
                  class="text-n-slate-11"
                >
                  {{ t('FACEBOOK_LEADS.OUTREACH.CONVERSATION_DELETED') }}
                </span>
                <span
                  v-else
                  :class="
                    result.status === 'skipped'
                      ? 'text-n-slate-11'
                      : 'text-n-ruby-11'
                  "
                >
                  {{ result.error }}
                </span>
                <Button
                  v-if="result.conversation_id"
                  :label="t('FACEBOOK_LEADS.OUTREACH.VIEW_CONVERSATION')"
                  variant="link"
                  size="xs"
                  @click="openConversation(result.conversation_id)"
                />
              </li>
            </ul>
            <dl class="grid grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols-2">
              <div
                v-for="answer in answers"
                :key="answer.key"
                class="flex flex-col gap-1 min-w-0"
              >
                <dt class="text-xs text-n-slate-11">{{ answer.label }}</dt>
                <dd class="text-sm break-words text-n-slate-12">
                  {{ answer.value }}
                </dd>
              </div>
            </dl>
            <dl
              v-if="adDetails.length"
              class="grid grid-cols-1 gap-x-6 gap-y-4 pt-4 border-t border-n-weak sm:grid-cols-3"
            >
              <div
                v-for="detail in adDetails"
                :key="detail.label"
                class="flex flex-col gap-1 min-w-0"
              >
                <dt class="text-xs text-n-slate-11">{{ detail.label }}</dt>
                <dd class="text-sm break-words text-n-slate-12">
                  {{ detail.value }}
                </dd>
              </div>
            </dl>
            <span
              v-if="lead.is_organic"
              class="self-start px-1.5 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-11"
            >
              {{ t('FACEBOOK_LEADS.CARD.ORGANIC') }}
            </span>
          </div>
        </div>
      </div>
    </template>
  </CardLayout>
</template>
