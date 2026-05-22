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

const description = computed(() =>
  t('CONVERSATION.LABELS.ADD_DIALOG.DESCRIPTION', {
    label: props.label.title,
  })
);

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
    :title="t('CONVERSATION.LABELS.ADD_DIALOG.TITLE')"
    :description="description"
    :confirm-button-label="t('CONVERSATION.LABELS.ADD_DIALOG.CONFIRM')"
    @confirm="handleDialogConfirm"
  />
</template>
