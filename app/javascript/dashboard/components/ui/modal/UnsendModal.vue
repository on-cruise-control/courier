<script>
export default {
  name: 'UnsendModal',
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    title: {
      type: String,
      default: '',
    },
    message: {
      type: String,
      default: '',
    },
    confirmText: {
      type: String,
      default: '',
    },
    rejectText: {
      type: String,
      default: '',
    },
  },
  emits: ['update:show', 'close', 'confirm'],
  methods: {
    onClose() {
      this.$emit('update:show', false);
      this.$emit('close');
    },
    onConfirm() {
      this.$emit('confirm');
      this.onClose();
    },
  },
};
</script>

<template>
  <wootModal :show="show" :on-close="onClose">
    <div class="unsend-modal" @keyup.esc="onClose">
      <div class="unsend-modal__header">
        <h2 class="text-slate-900 dark:text-slate-100">
          {{ title }}
        </h2>
      </div>
      <div class="unsend-modal__body">
        <p class="text-slate-700 dark:text-slate-200">
          {{ message }}
        </p>
      </div>
      <div class="unsend-modal__footer">
        <wootButton
          color-scheme="secondary"
          variant="clear"
          size="small"
          @click="onClose"
        >
          {{ rejectText }}
        </wootButton>
        <wootButton
          color-scheme="danger"
          variant="solid"
          size="small"
          @click="onConfirm"
        >
          {{ confirmText }}
        </wootButton>
      </div>
    </div>
  </wootModal>
</template>

<style lang="scss" scoped>
.unsend-modal {
  @apply p-6;

  &__header {
    @apply mb-4;
  }

  &__body {
    @apply mb-6;
  }

  &__footer {
    @apply flex justify-end gap-2;
  }
}
</style>
