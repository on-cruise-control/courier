<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  show: { type: Boolean, default: false },
  template: { type: Object, default: null },
});

const emit = defineEmits(['update:show', 'onSubmit']);

const localShow = ref(props.show);
watch(() => props.show, v => {
  localShow.value = v;
  if (v) category.value = 'UTILITY';
});

const { t } = useI18n();

const category = ref('UTILITY');
const isSubmitting = ref(false);

const CATEGORIES = [
  {
    value: 'MARKETING',
    label: t('TWILIO_TEMPLATES.APPROVAL.CATEGORIES.MARKETING'),
    description: t('TWILIO_TEMPLATES.APPROVAL.CATEGORIES.MARKETING_DESC'),
  },
  {
    value: 'UTILITY',
    label: t('TWILIO_TEMPLATES.APPROVAL.CATEGORIES.UTILITY'),
    description: t('TWILIO_TEMPLATES.APPROVAL.CATEGORIES.UTILITY_DESC'),
  },
];

function close() {
  localShow.value = false;
  emit('update:show', false);
}

async function handleSubmit() {
  isSubmitting.value = true;
  try {
    await emit('onSubmit', {
      name: props.template?.friendly_name,
      category: category.value,
    });
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="close">
    <woot-modal-header :header-title="t('TWILIO_TEMPLATES.APPROVAL.TITLE')" />
    <div class="px-8 py-6 flex flex-col gap-5">
      <p class="text-sm text-n-slate-11">
        {{ t('TWILIO_TEMPLATES.APPROVAL.DESCRIPTION') }}
      </p>

      <!-- Category selection -->
      <div class="flex flex-col gap-2">
        <p class="text-sm font-medium text-n-slate-12">
          <span class="text-ruby-500 mr-0.5">*</span>
          {{ t('TWILIO_TEMPLATES.APPROVAL.SELECT_CATEGORY') }}
        </p>
        <div class="flex flex-col gap-2">
          <label
            v-for="cat in CATEGORIES"
            :key="cat.value"
            class="flex items-start gap-3 p-3.5 border-2 rounded-xl cursor-pointer transition-all"
            :class="
              category === cat.value
                ? 'border-[#182933] bg-[#182933]/5'
                : 'border-n-weak hover:border-n-slate-5 bg-n-slate-1'
            "
          >
            <input
              v-model="category"
              type="radio"
              :value="cat.value"
              class="mt-0.5 accent-[#182933] shrink-0"
            />
            <div>
              <p
                class="text-sm font-medium"
                :class="category === cat.value ? 'text-[#182933]' : 'text-n-slate-12'"
              >
                {{ cat.label }}
              </p>
              <p class="text-xs text-n-slate-9 mt-0.5 leading-relaxed">
                {{ cat.description }}
              </p>
            </div>
          </label>
        </div>
      </div>

      <div class="flex justify-end gap-3 pt-1">
        <button
          class="px-4 py-2 text-sm border border-n-weak rounded-lg hover:bg-n-slate-2 transition-colors text-n-slate-11"
          @click="close"
        >
          {{ t('TWILIO_TEMPLATES.FORM.CANCEL') }}
        </button>
        <button
          class="px-4 py-2 text-sm bg-[#182933] hover:bg-[#182933]/90 text-white rounded-lg transition-colors disabled:opacity-50"
          :disabled="isSubmitting"
          @click="handleSubmit"
        >
          {{
            isSubmitting
              ? t('TWILIO_TEMPLATES.APPROVAL.SUBMITTING')
              : t('TWILIO_TEMPLATES.APPROVAL.SUBMIT')
          }}
        </button>
      </div>
    </div>
  </woot-modal>
</template>
