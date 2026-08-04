<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { useConversationLabels } from 'dashboard/composables/useConversationLabels';

const props = defineProps({
  label: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const { addLabelToConversation } = useConversationLabels();

const dialogRef = ref(null);

const capitalizedLabel = computed(() => {
  const title = props.label.title ?? '';
  return title.charAt(0).toUpperCase() + title.slice(1);
});

const LABEL_KEYS = {
  escalation: {
    title: 'CONVERSATION.LABELS.ADD_DIALOG.ESCALATION_TITLE',
    description: 'CONVERSATION.LABELS.ADD_DIALOG.ESCALATION_DESCRIPTION',
  },
  handoff: {
    title: 'CONVERSATION.LABELS.ADD_DIALOG.HANDOFF_TITLE',
    description: 'CONVERSATION.LABELS.ADD_DIALOG.HANDOFF_DESCRIPTION',
  },
};

const dialogTitle = computed(() => {
  const key = LABEL_KEYS[props.label.title]?.title;
  return key ? t(key) : '';
});

const description = computed(() => {
  const key = LABEL_KEYS[props.label.title]?.description;
  return key ? t(key, { label: props.label.title }) : '';
});

const handleDialogConfirm = async () => {
  if (!props.label?.title) return;

  await addLabelToConversation(props.label);
  dialogRef.value?.close();
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    :title="dialogTitle"
    :description="description"
    :confirm-button-label="t('CONVERSATION.LABELS.ADD_DIALOG.CONFIRM', { label: capitalizedLabel })"
    @confirm="handleDialogConfirm"
  />
</template>
