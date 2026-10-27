<script setup>
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import FacebookLeadsAPI from 'dashboard/api/facebookLeads';
import { buildLeadAnswers } from 'dashboard/routes/dashboard/leads/leadAnswers';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const router = useRouter();
const accountId = useMapGetter('getCurrentAccountId');
const chat = useMapGetter('getSelectedChat');

const lead = ref(null);
const leadRef = computed(
  () => chat.value?.additional_attributes?.facebook_lead
);

const answers = computed(() =>
  buildLeadAnswers(lead.value, lead.value.questions)
);

const adDetails = computed(() =>
  [
    {
      label: t('FACEBOOK_LEADS.SIDEBAR.CAMPAIGN'),
      value: lead.value.campaign_name,
    },
    { label: t('FACEBOOK_LEADS.SIDEBAR.ADSET'), value: lead.value.adset_name },
    { label: t('FACEBOOK_LEADS.SIDEBAR.AD'), value: lead.value.ad_name },
  ].filter(detail => detail.value)
);

const details = computed(() => [
  { label: t('FACEBOOK_LEADS.SIDEBAR.FORM'), value: lead.value.form_name },
  ...answers.value,
  ...adDetails.value,
]);

const viewLead = () =>
  router.push(
    `${frontendURL(`accounts/${accountId.value}/leads/forms/${lead.value.form_id}`)}#${lead.value.id}`
  );

// Agents without access to the Facebook page simply do not see the block
watch(
  leadRef,
  async leadReference => {
    lead.value = null;
    if (!leadReference) return;
    try {
      lead.value = (await FacebookLeadsAPI.getLead(leadReference.id)).data;
    } catch (error) {
      lead.value = null;
    }
  },
  { immediate: true }
);
</script>

<template>
  <div v-if="lead" class="flex flex-col gap-3 px-4 pt-2 pb-4">
    <dl class="flex flex-col gap-2">
      <div v-for="detail in details" :key="detail.label" class="flex gap-2">
        <dt class="w-24 text-xs text-n-slate-11 shrink-0">
          {{ detail.label }}
        </dt>
        <dd class="text-xs break-words text-n-slate-12">{{ detail.value }}</dd>
      </div>
    </dl>
    <Button
      :label="t('FACEBOOK_LEADS.SIDEBAR.VIEW')"
      variant="link"
      size="xs"
      class="self-start"
      @click="viewLead"
    />
  </div>
</template>
