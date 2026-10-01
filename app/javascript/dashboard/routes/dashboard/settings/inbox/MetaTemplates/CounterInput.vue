<script setup>
const props = defineProps({
  modelValue: { type: String, default: '' },
  maxlength: { type: Number, required: true },
  placeholder: { type: String, default: '' },
  multiline: { type: Boolean, default: false },
  rows: { type: Number, default: 2 },
});

defineEmits(['update:modelValue']);
</script>

<template>
  <div class="relative">
    <textarea
      v-if="multiline"
      :value="modelValue"
      :maxlength="maxlength"
      :rows="rows"
      class="w-full rounded-lg border border-n-slate-6 bg-transparent px-3 py-2 pr-14 text-sm"
      :placeholder="placeholder"
      @input="$emit('update:modelValue', $event.target.value)"
    />
    <input
      v-else
      type="text"
      :value="modelValue"
      :maxlength="maxlength"
      class="w-full rounded-lg border border-n-slate-6 bg-transparent px-3 py-1.5 pr-14 text-sm"
      :placeholder="placeholder"
      @input="$emit('update:modelValue', $event.target.value)"
    />
    <span
      class="absolute right-2.5 text-[10px] text-n-slate-9 pointer-events-none"
      :class="multiline ? 'bottom-2' : 'top-1/2 -translate-y-1/2'"
    >
      {{ (modelValue || '').length }}/{{ props.maxlength }}
    </span>
  </div>
</template>
