<script>
import CardButton from 'shared/components/CardButton.vue';

export default {
  components: {
    CardButton,
  },
  props: {
    title: {
      type: String,
      default: '',
    },
    description: {
      type: String,
      default: '',
    },
    mediaUrl: {
      type: String,
      default: '',
    },
    actions: {
      type: Array,
      default: () => [],
    },
  },
  emits: ['postback'],
  methods: {
    onPostback(payload) {
      if (this.mediaUrl) {
        window.open(this.mediaUrl, '_blank', 'noopener,noreferrer');
      }
      this.$emit('postback', payload);
    },
  },
};
</script>

<template>
  <div
    class="card-message chat-bubble agent bg-n-background dark:bg-n-solid-3 w-56 flex-none rounded-lg overflow-hidden"
  >
    <img
      class="w-full object-contain max-h-[150px] rounded-[5px]"
      :src="mediaUrl"
    />
    <div class="card-body">
      <h4
        class="!text-base !font-medium !mt-1 !mb-1 !leading-[1.5] text-n-slate-12"
      >
        {{ title }}
      </h4>
      <p class="!mb-1 text-n-slate-11">
        {{ description }}
      </p>
      <CardButton
        v-for="action in actions"
        :key="action.payload || action.uri"
        :action="action"
        @postback="onPostback"
      />
    </div>
  </div>
</template>
