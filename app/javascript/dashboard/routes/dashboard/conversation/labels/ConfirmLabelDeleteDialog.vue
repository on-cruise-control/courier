<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { useConversationLabels } from 'dashboard/composables/useConversationLabels';

const props = defineProps({
  labelTitle: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
const { removeLabelFromConversation } = useConversationLabels();

const dialogRef = ref(null);

const description = computed(() =>
  t('CONVERSATION.LABELS.DELETE_DIALOG.DESCRIPTION', {
    label: props.labelTitle,
  })
);

const handleDialogConfirm = async () => {
  if (!props.labelTitle) return;

  await removeLabelFromConversation(props.labelTitle);
  dialogRef.value?.close();
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    :title="t('CONVERSATION.LABELS.DELETE_DIALOG.TITLE')"
    :description="description"
    :confirm-button-label="t('CONVERSATION.LABELS.DELETE_DIALOG.CONFIRM')"
    @confirm="handleDialogConfirm"
  />
</template>
