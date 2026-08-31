<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import SectionLayout from '../../account/components/SectionLayout.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const store = useStore();

const currentAccount = useMapGetter('getCurrentAccountId');

const escalationEmails = ref([]);
const newEmail = ref('');
const emailError = ref('');

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const validateEmail = email => {
  if (!email) {
    return false;
  }
  return EMAIL_REGEX.test(email.trim());
};

const saveEscalationEmails = async () => {
  try {
    await store.dispatch('accounts/update', {
      id: currentAccount.value,
      escalation_emails: escalationEmails.value,
      options: { silent: true },
    });
    useAlert(t('GENERAL_SETTINGS.FORM.ESCALATION_EMAILS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.ESCALATION_EMAILS.API.ERROR'));
  }
};

const addEmail = () => {
  emailError.value = '';
  if (!newEmail.value.trim()) return;

  const email = newEmail.value.trim().toLowerCase();

  if (!validateEmail(email)) {
    emailError.value = t(
      'GENERAL_SETTINGS.FORM.ESCALATION_EMAILS.INVALID_EMAIL'
    );
    return;
  }
  if (escalationEmails.value.includes(email)) {
    emailError.value = t(
      'GENERAL_SETTINGS.FORM.ESCALATION_EMAILS.DUPLICATE_EMAIL'
    );
    return;
  }

  escalationEmails.value.push(email);
  newEmail.value = '';
  emailError.value = '';
  saveEscalationEmails();
};

const removeEmail = index => {
  escalationEmails.value.splice(index, 1);
  saveEscalationEmails();
};

onMounted(() => {
  const account = store.getters['accounts/getAccount'](currentAccount.value);
  escalationEmails.value = account.escalation_emails || [];
});

const hasEscalationEmails = computed(() => escalationEmails.value.length > 0);
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.ESCALATION_EMAILS.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.ESCALATION_EMAILS.NOTE')"
    with-border
  >
    <div class="space-y-4">
      <WithLabel
        :label="t('GENERAL_SETTINGS.FORM.ESCALATION_EMAILS.LABEL')"
        :has-error="!!emailError"
        :error-message="emailError"
      >
        <div class="flex gap-2">
          <NextInput
            v-model="newEmail"
            type="email"
            class="flex-1"
            :placeholder="
              t('GENERAL_SETTINGS.FORM.ESCALATION_EMAILS.PLACEHOLDER')
            "
            @keypress.enter="addEmail"
          />
          <NextButton blue @click="addEmail">
            {{ t('GENERAL_SETTINGS.FORM.ESCALATION_EMAILS.ADD_BUTTON') }}
          </NextButton>
        </div>
      </WithLabel>

      <div v-if="hasEscalationEmails" class="space-y-2">
        <p class="text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ t('GENERAL_SETTINGS.FORM.ESCALATION_EMAILS.CONFIGURED_EMAILS') }}
        </p>
        <div class="flex flex-wrap gap-2">
          <div
            v-for="(email, index) in escalationEmails"
            :key="index"
            class="inline-flex items-center gap-2 px-3 py-1.5 bg-slate-100 dark:bg-slate-700 rounded-full border border-slate-200 dark:border-slate-600 group hover:border-slate-300 dark:hover:border-slate-500 transition-colors"
          >
            <span class="text-sm text-slate-900 dark:text-slate-100">
              {{ email }}
            </span>
            <button
              class="text-slate-500 hover:text-red-600 dark:text-slate-400 dark:hover:text-red-400 transition-colors"
              :aria-label="`Remove ${email}`"
              @click="removeEmail(index)"
            >
              <fluent-icon icon="dismiss" size="14" />
            </button>
          </div>
        </div>
      </div>

      <div
        v-else
        class="p-4 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg"
      >
        <p class="text-sm text-yellow-800 dark:text-yellow-200">
          {{ t('GENERAL_SETTINGS.FORM.ESCALATION_EMAILS.EMPTY_STATE') }}
        </p>
      </div>
    </div>
  </SectionLayout>
</template>
