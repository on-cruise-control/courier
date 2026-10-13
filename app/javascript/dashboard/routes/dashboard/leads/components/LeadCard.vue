<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { messageTimestamp } from 'shared/helpers/timeHelper';

const props = defineProps({
  lead: { type: Object, required: true },
  questions: { type: Array, default: () => [] },
  isExpanded: { type: Boolean, default: false },
});

const emit = defineEmits(['toggle']);

const { t } = useI18n();

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

const humanize = key =>
  key.charAt(0).toUpperCase() + key.slice(1).replace(/_/g, ' ');

// Answered questions only, labelled with the question text from the form definition
const answers = computed(() =>
  props.lead.field_data
    .map(field => ({
      key: field.name,
      label:
        props.questions.find(q => q.key === field.name)?.label ||
        humanize(field.name),
      // Meta omits `values` for unanswered optional questions
      value: (field.values || []).join(', ').trim(),
    }))
    // inbox_url is a Meta-added field that users never fill in
    .filter(answer => answer.value && answer.key !== 'inbox_url')
);

// Forms without a name question fall back to their first answer as the title
const title = computed(
  () =>
    props.lead.name ||
    answers.value[0]?.value ||
    t('FACEBOOK_LEADS.CARD.UNKNOWN_NAME')
);

const adDetails = computed(() =>
  [
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
      </div>
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
