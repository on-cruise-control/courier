<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { dynamicTime, messageTimestamp } from 'shared/helpers/timeHelper';

const props = defineProps({
  form: { type: Object, required: true },
  pageName: { type: String, default: '' },
  isExpanded: { type: Boolean, default: false },
});

const emit = defineEmits(['toggle', 'open']);

const { t } = useI18n();

const toUnix = value => Math.floor(new Date(value).getTime() / 1000);

// Meta adds this question to every form; users never fill it in
const questions = computed(() =>
  props.form.questions.filter(question => question.key !== 'inbox_url')
);
const isActive = computed(() => props.form.status === 'ACTIVE');
const createdAt = computed(() =>
  props.form.form_created_at
    ? messageTimestamp(toUnix(props.form.form_created_at), 'MMM dd, yyyy')
    : '—'
);
const lastSynced = computed(() =>
  props.form.last_synced_at
    ? t('FACEBOOK_LEADS.FORMS.LAST_SYNCED', {
        time: dynamicTime(toUnix(props.form.last_synced_at)),
      })
    : t('FACEBOOK_LEADS.FORMS.NEVER_SYNCED')
);
</script>

<template>
  <CardLayout layout="row" class="cursor-pointer" @click="emit('open')">
    <div class="flex items-center justify-start flex-1 gap-4 min-w-0">
      <div
        class="flex items-center justify-center flex-shrink-0 rounded-full size-[42px] bg-n-alpha-2"
      >
        <span class="i-lucide-file-text size-5 text-n-slate-11" />
      </div>
      <div class="flex flex-col gap-0.5 flex-1 min-w-0">
        <div class="flex flex-wrap items-center gap-x-4 gap-y-1">
          <span class="text-base font-medium truncate text-n-slate-12">
            {{ form.name }}
          </span>
          <span
            class="px-1.5 py-0.5 text-xs font-medium rounded-md"
            :class="
              isActive
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-alpha-2 text-n-slate-11'
            "
          >
            {{ form.status }}
          </span>
          <span class="inline-flex items-center gap-1 min-w-0">
            <span class="i-lucide-facebook size-3.5 text-n-slate-10" />
            <span class="text-sm truncate text-n-slate-11">{{ pageName }}</span>
          </span>
        </div>
        <div class="flex flex-wrap items-center justify-start gap-x-3 gap-y-1">
          <span class="text-sm text-n-slate-11">
            {{
              t('FACEBOOK_LEADS.FORMS.LEADS_COUNT', {
                count: form.leads_count,
              })
            }}
          </span>
          <div class="w-px h-3 bg-n-slate-6" />
          <span class="text-sm text-n-slate-11">
            {{ t('FACEBOOK_LEADS.FORMS.CREATED', { date: createdAt }) }}
          </span>
          <div class="w-px h-3 bg-n-slate-6" />
          <span class="text-sm text-n-slate-11">{{ lastSynced }}</span>
        </div>
      </div>
    </div>

    <div class="flex items-center gap-1" @click.stop>
      <Button
        icon="i-lucide-chevron-down"
        variant="ghost"
        color="slate"
        size="xs"
        :class="{ 'rotate-180': isExpanded }"
        @click="emit('toggle')"
      />
    </div>

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
            <dl class="grid grid-cols-2 gap-x-6 gap-y-4 sm:grid-cols-4">
              <div class="flex flex-col gap-1 min-w-0">
                <dt class="text-xs text-n-slate-11">
                  {{ t('FACEBOOK_LEADS.FORMS.FORM_ID') }}
                </dt>
                <dd class="text-sm break-all text-n-slate-12">
                  {{ form.form_id }}
                </dd>
              </div>
              <div class="flex flex-col gap-1">
                <dt class="text-xs text-n-slate-11">
                  {{ t('FACEBOOK_LEADS.FORMS.LOCALE') }}
                </dt>
                <dd class="text-sm text-n-slate-12">
                  {{ form.locale || '—' }}
                </dd>
              </div>
              <div class="flex flex-col gap-1">
                <dt class="text-xs text-n-slate-11">
                  {{ t('FACEBOOK_LEADS.FORMS.META_LEADS') }}
                </dt>
                <dd class="text-sm text-n-slate-12">
                  {{ form.meta_leads_count ?? '—' }}
                </dd>
              </div>
              <div class="flex flex-col gap-1">
                <dt class="text-xs text-n-slate-11">
                  {{ t('FACEBOOK_LEADS.FORMS.SYNCED_LEADS') }}
                </dt>
                <dd class="text-sm text-n-slate-12">{{ form.leads_count }}</dd>
              </div>
            </dl>
            <div class="flex flex-col gap-2">
              <span class="text-xs text-n-slate-11">
                {{ t('FACEBOOK_LEADS.FORMS.QUESTIONS') }}
              </span>
              <ul class="flex flex-col divide-y divide-n-weak">
                <li
                  v-for="question in questions"
                  :key="question.id || question.key"
                  class="flex flex-wrap items-center justify-between gap-2 py-2"
                >
                  <span class="text-sm text-n-slate-12">
                    {{ question.label || question.key }}
                  </span>
                  <span class="flex items-center gap-2 text-xs text-n-slate-11">
                    <code class="px-1.5 py-0.5 rounded bg-n-alpha-2">
                      {{ question.key }}
                    </code>
                    <span>{{ question.type }}</span>
                  </span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </template>
  </CardLayout>
</template>
