<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useWindowSize } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import OfferForm from '../components/OfferForm.vue';
import OfferShow from '../components/OfferShow.vue';

const ITEMS_PER_PAGE = 10;
const TABLET_BREAKPOINT = 767;
const DOCUMENT_TEXT_REFRESH_DELAY_MS = 2000;

const store = useStore();
const { t } = useI18n();
const { width: windowWidth } = useWindowSize();
const formDialogWidth = computed(() =>
  windowWidth.value >= TABLET_BREAKPOINT ? '2xl' : 'lg'
);

const createDialogRef = ref(null);
const createFormKey = ref(0);
const editDialogRef = ref(null);
const editFormKey = ref(0);
const editTarget = ref(null);
const deleteDialogRef = ref(null);
const deleteTarget = ref(null);
const showDialogRef = ref(null);
const showTarget = ref(null);
const currentPage = ref(1);

const offers = computed(() => store.getters['offers/getRecords']);
const uiFlags = computed(() => store.getters['offers/getUIFlags']);
const paginatedOffers = computed(() => {
  const start = (currentPage.value - 1) * ITEMS_PER_PAGE;
  return offers.value.slice(start, start + ITEMS_PER_PAGE);
});

watch(offers, () => {
  const totalPages = Math.max(
    1,
    Math.ceil(offers.value.length / ITEMS_PER_PAGE)
  );
  if (currentPage.value > totalPages) currentPage.value = totalPages;
});

const fetchOffers = async () => {
  try {
    await store.dispatch('offers/fetch');
    currentPage.value = 1;
  } catch (error) {
    useAlert(t('OFFERS_MGMT.ERROR_FETCHING'));
  }
};

onMounted(fetchOffers);

const openCreateDialog = () => {
  createFormKey.value += 1;
  createDialogRef.value?.open();
};
const closeCreateDialog = () => createDialogRef.value?.close();

const refreshOffersSilently = () => {
  store.dispatch('offers/fetch', { silent: true }).catch(() => {});
};

const handleCreate = async payload => {
  try {
    await store.dispatch('offers/create', payload);
    useAlert(t('OFFERS_MGMT.CREATE_SUCCESS'));
    closeCreateDialog();
    setTimeout(refreshOffersSilently, DOCUMENT_TEXT_REFRESH_DELAY_MS);
  } catch (error) {
    useAlert(t('OFFERS_MGMT.ERROR_CREATE'));
  }
};

const openEditDialog = offer => {
  editTarget.value = offer;
  editFormKey.value += 1;
  editDialogRef.value?.open();
};
const closeEditDialog = () => editDialogRef.value?.close();
const handleEditDialogClosed = () => {
  editTarget.value = null;
};

const handleEdit = async payload => {
  if (!editTarget.value) return;
  try {
    await store.dispatch('offers/update', {
      id: editTarget.value.id,
      ...payload,
    });
    useAlert(t('OFFERS_MGMT.EDIT_SUCCESS'));
    closeEditDialog();
  } catch (error) {
    useAlert(t('OFFERS_MGMT.ERROR_UPDATE'));
  }
};

const openDeleteDialog = offer => {
  deleteTarget.value = offer;
  deleteDialogRef.value?.open();
};
const closeDeleteDialog = () => deleteDialogRef.value?.close();
const handleDeleteDialogClosed = () => {
  deleteTarget.value = null;
};

const handleDelete = async () => {
  if (!deleteTarget.value) return;
  try {
    await store.dispatch('offers/delete', deleteTarget.value.id);
    useAlert(t('OFFERS_MGMT.DELETE_SUCCESS'));
    closeDeleteDialog();
  } catch (error) {
    useAlert(t('OFFERS_MGMT.ERROR_DELETE'));
  }
};

const openShowDialog = offer => {
  showTarget.value = offer;
  showDialogRef.value?.open();
};
const closeShowDialog = () => showDialogRef.value?.close();
const handleShowDialogClosed = () => {
  showTarget.value = null;
};
const handleShowEdit = offer => {
  closeShowDialog();
  openEditDialog(offer);
};

const formatDate = value => {
  if (!value) return '—';
  return new Intl.DateTimeFormat(undefined, {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
  }).format(new Date(value));
};
</script>

<template>
  <div class="flex h-full w-full overflow-hidden">
    <div
      class="mx-auto flex h-full w-full min-w-full max-w-[60rem] flex-col px-6 pt-6 md:px-8 lg:min-w-[35rem]"
    >
      <div class="flex-shrink-0 pb-6">
        <div
          class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between"
        >
          <div class="space-y-1">
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ t('OFFERS_MGMT.LIST_HEADING') }}
            </h2>
            <p class="text-sm text-n-slate-11">
              {{ t('OFFERS_MGMT.LIST_SUBHEADING') }}
            </p>
          </div>
          <Button icon="i-lucide-plus" @click="openCreateDialog">
            {{ t('OFFERS_MGMT.LIST_CREATE_BUTTON') }}
          </Button>
        </div>
      </div>

      <div
        class="flex-1 overflow-y-auto pb-10 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
      >
        <div
          v-if="uiFlags.isFetching"
          class="flex items-center justify-center py-20"
        >
          <Spinner />
        </div>
        <div v-else class="flex flex-col gap-3">
          <article
            v-for="offer in paginatedOffers"
            :key="offer.id"
            class="flex flex-wrap items-center gap-3 rounded-2xl border border-n-gray-4 bg-white px-5 py-3 shadow-sm transition-colors hover:border-n-alpha-4 hover:bg-n-alpha-1 cursor-pointer dark:bg-n-solid-2 dark:hover:bg-n-solid-3 xl:grid xl:grid-cols-[2fr_auto_auto_auto_auto] xl:items-center xl:gap-4"
            @click="openShowDialog(offer)"
          >
            <div class="min-w-0 w-full space-y-1">
              <span class="text-[11px] uppercase tracking-wide text-n-slate-10">
                {{ t('OFFERS_MGMT.TABLE.TITLE') }}
              </span>
              <div
                :title="offer.title"
                class="truncate text-base font-semibold text-n-slate-12"
              >
                {{ offer.title }}
              </div>
            </div>

            <div class="min-w-[6rem] space-y-1 text-sm text-n-slate-11">
              <span class="text-[11px] uppercase tracking-wide text-n-slate-10">
                {{ t('OFFERS_MGMT.TABLE.START_DATE') }}
              </span>
              <div class="whitespace-nowrap text-n-slate-12">
                {{ formatDate(offer.start_date) }}
              </div>
            </div>

            <div class="min-w-[6rem] space-y-1 text-sm text-n-slate-11">
              <span class="text-[11px] uppercase tracking-wide text-n-slate-10">
                {{ t('OFFERS_MGMT.TABLE.END_DATE') }}
              </span>
              <div class="whitespace-nowrap text-n-slate-12">
                {{ formatDate(offer.end_date) }}
              </div>
            </div>

            <div class="min-w-[7rem] text-sm text-n-slate-11">
              <a
                v-if="offer.offer_document"
                :href="offer.offer_document"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-1 text-n-brand hover:underline"
                @click.stop
              >
                <i class="i-lucide-file-text size-3.5" />
                {{ t('OFFERS_MGMT.TABLE.VIEW_DOCUMENT') }}
              </a>
              <span v-else>{{ t('OFFERS_MGMT.TABLE.NO_PDF') }}</span>
            </div>

            <div class="ml-auto flex items-center gap-1" @click.stop>
              <Button
                icon="i-lucide-pencil"
                slate
                ghost
                xs
                :aria-label="t('OFFERS_MGMT.TABLE.EDIT_ACTION')"
                :title="t('OFFERS_MGMT.TABLE.EDIT_ACTION')"
                @click="openEditDialog(offer)"
              />
              <Button
                icon="i-lucide-trash-2"
                ruby
                ghost
                xs
                :aria-label="t('OFFERS_MGMT.TABLE.DELETE_ACTION')"
                :title="t('OFFERS_MGMT.TABLE.DELETE_ACTION')"
                @click="openDeleteDialog(offer)"
              />
            </div>
          </article>

          <div
            v-if="!offers.length"
            class="col-span-full rounded-2xl border border-dashed border-n-alpha-3 bg-white py-16 text-center text-sm text-n-slate-11 dark:bg-n-solid-2"
          >
            {{ t('OFFERS_MGMT.EMPTY_MESSAGE') }}
          </div>
        </div>
      </div>
      <PaginationFooter
        v-if="offers.length"
        class="flex-shrink-0 mb-2"
        :current-page="currentPage"
        :total-items="offers.length"
        :items-per-page="ITEMS_PER_PAGE"
        @update:current-page="currentPage = $event"
      />

      <Dialog
        ref="createDialogRef"
        :width="formDialogWidth"
        :show-cancel-button="false"
        :show-confirm-button="false"
        @close="() => (createFormKey += 1)"
      >
        <OfferForm
          :key="createFormKey"
          :heading="t('OFFERS_MGMT.CREATE_HEADING')"
          :submit-label="t('OFFERS_MGMT.CREATE_SUBMIT')"
          :is-submitting="uiFlags.isCreating"
          @submit="handleCreate"
          @cancel="closeCreateDialog"
        />
      </Dialog>

      <Dialog
        ref="editDialogRef"
        :width="formDialogWidth"
        :show-cancel-button="false"
        :show-confirm-button="false"
        @close="handleEditDialogClosed"
      >
        <OfferForm
          v-if="editTarget"
          :key="editFormKey"
          :offer="editTarget"
          :heading="t('OFFERS_MGMT.EDIT_HEADING')"
          :submit-label="t('OFFERS_MGMT.EDIT_SUBMIT')"
          :is-submitting="uiFlags.isUpdating"
          @submit="handleEdit"
          @cancel="closeEditDialog"
        />
      </Dialog>

      <Dialog
        ref="deleteDialogRef"
        type="alert"
        :title="t('OFFERS_MGMT.DELETE_CONFIRM_TITLE')"
        :description="
          deleteTarget
            ? t('OFFERS_MGMT.DELETE_CONFIRM_MESSAGE', {
                title: deleteTarget.title,
              })
            : ''
        "
        :confirm-button-label="t('OFFERS_MGMT.DELETE_CONFIRM_SUBMIT')"
        :cancel-button-label="t('OFFERS_MGMT.DELETE_CONFIRM_CANCEL')"
        :is-loading="uiFlags.isDeleting"
        @confirm="handleDelete"
        @close="handleDeleteDialogClosed"
      />

      <Dialog
        ref="showDialogRef"
        width="3xl"
        :show-cancel-button="false"
        :show-confirm-button="false"
        @close="handleShowDialogClosed"
      >
        <OfferShow
          v-if="showTarget"
          :offer="showTarget"
          @edit="handleShowEdit"
        />
      </Dialog>
    </div>
  </div>
</template>
