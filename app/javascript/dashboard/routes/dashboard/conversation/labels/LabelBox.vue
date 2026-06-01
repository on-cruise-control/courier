<script>
import { ref } from 'vue';
import { mapGetters } from 'vuex';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useConversationLabels } from 'dashboard/composables/useConversationLabels';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import ConfirmLabelAddDialog from './ConfirmLabelAddDialog.vue';
import ConfirmLabelDeleteDialog from './ConfirmLabelDeleteDialog.vue';
import Spinner from 'shared/components/Spinner.vue';
import LabelDropdown from 'shared/components/ui/label/LabelDropdown.vue';
import AddLabel from 'shared/components/ui/dropdown/AddLabel.vue';

export default {
  components: {
    ConfirmLabelAddDialog,
    ConfirmLabelDeleteDialog,
    Spinner,
    LabelDropdown,
    AddLabel,
  },
  setup() {
    const { isAdmin } = useAdmin();

    const {
      savedLabels,
      activeLabels,
      accountLabels,
      addLabelToConversation,
    } = useConversationLabels();

    const CONFIRM_REQUIRED_LABELS = ['escalation', 'handoff'];

    const showSearchDropdownLabel = ref(false);
    const confirmAddLabelDialogRef = ref(null);
    const confirmDeleteLabelDialogRef = ref(null);
    const labelPendingAddition = ref({});
    const labelPendingDeletion = ref('');

    const toggleLabels = () => {
      showSearchDropdownLabel.value = !showSearchDropdownLabel.value;
    };

    const closeDropdownLabel = () => {
      showSearchDropdownLabel.value = false;
    };

    const openConfirmDeleteLabelDialog = label => {
      labelPendingDeletion.value = label;
      confirmDeleteLabelDialogRef.value?.dialogRef.open();
    };

    const openConfirmAddLabelDialog = label => {
      if (CONFIRM_REQUIRED_LABELS.includes(label.title)) {
        labelPendingAddition.value = label;
        confirmAddLabelDialogRef.value?.dialogRef.open();
      } else {
        addLabelToConversation(label);
      }
    };

    const keyboardEvents = {
      KeyL: {
        action: e => {
          e.preventDefault();
          toggleLabels();
        },
      },
      Escape: {
        action: () => {
          if (showSearchDropdownLabel.value) {
            toggleLabels();
          }
        },
        allowOnFocusedInput: true,
      },
    };
    useKeyboardEvents(keyboardEvents);
    return {
      isAdmin,
      savedLabels,
      activeLabels,
      accountLabels,
      addLabelToConversation,
      confirmAddLabelDialogRef,
      confirmDeleteLabelDialogRef,
      labelPendingAddition,
      labelPendingDeletion,
      showSearchDropdownLabel,
      closeDropdownLabel,
      toggleLabels,
      openConfirmAddLabelDialog,
      openConfirmDeleteLabelDialog,
    };
  },
  data() {
    return {
      selectedLabels: [],
    };
  },

  computed: {
    ...mapGetters({
      conversationUiFlags: 'conversationLabels/getUIFlags',
    }),
  },
};
</script>

<template>
  <div class="sidebar-labels-wrap">
    <div
      v-if="!conversationUiFlags.isFetching"
      class="contact-conversation--list"
    >
      <div
        v-on-clickaway="closeDropdownLabel"
        class="label-wrap flex flex-wrap"
        @keyup.esc="closeDropdownLabel"
      >
        <AddLabel @add="toggleLabels" />
        <woot-label
          v-for="label in activeLabels"
          :key="label.id"
          :title="label.title"
          :description="label.description"
          show-close
          :color="label.color"
          variant="smooth"
          class="max-w-[calc(100%-0.5rem)]"
          @remove="openConfirmDeleteLabelDialog"
        />

        <div
          :class="{
            'block visible': showSearchDropdownLabel,
            'hidden invisible': !showSearchDropdownLabel,
          }"
          class="border rounded-lg bg-n-alpha-3 top-6 backdrop-blur-[100px] absolute w-full shadow-lg border-n-strong dark:border-n-strong p-2 box-border z-[9999]"
        >
          <LabelDropdown
            v-if="showSearchDropdownLabel"
            :account-labels="accountLabels"
            :selected-labels="savedLabels"
            :allow-creation="isAdmin"
            @add="openConfirmAddLabelDialog"
            @remove="openConfirmDeleteLabelDialog"
          />
        </div>
      </div>
    </div>
    <Spinner v-else />
    <ConfirmLabelAddDialog
      ref="confirmAddLabelDialogRef"
      :label="labelPendingAddition"
    />
    <ConfirmLabelDeleteDialog
      ref="confirmDeleteLabelDialogRef"
      :label-title="labelPendingDeletion"
    />
  </div>
</template>

<style lang="scss" scoped>
.sidebar-labels-wrap {
  margin-bottom: 0;
}
.contact-conversation--list {
  width: 100%;

  .label-wrap {
    line-height: 1.5rem;
    position: relative;
  }
}
</style>
