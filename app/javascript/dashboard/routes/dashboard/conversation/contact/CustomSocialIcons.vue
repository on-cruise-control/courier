<script>
export default {
  props: {
    socialProfiles: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      socialMediaLinks: [
        { key: 'facebook', icon: 'i-ph-facebook-logo', link: 'https://facebook.com/' },
        { key: 'twitter', icon: 'i-ph-twitter-logo', link: 'https://twitter.com/' },
        { key: 'linkedin', icon: 'i-ph-linkedin-logo', link: 'https://linkedin.com/' },
        { key: 'github', icon: 'i-ph-github-logo', link: 'https://github.com/' },
        { key: 'instagram', icon: 'i-ph-instagram-logo', link: 'https://instagram.com/' },
        { key: 'telegram', icon: 'i-ph-telegram-logo', link: 'https://t.me/' },
        { key: 'tiktok', icon: 'i-ph-tiktok-logo', link: 'https://tiktok.com/@' },
      ],
    };
  },
  computed: {
    availableProfiles() {
      return this.socialMediaLinks.filter(
        mediaLink => !!this.socialProfiles[mediaLink.key]
      );
    },
  },
};
</script>

<template>
  <div v-if="availableProfiles.length" class="flex items-center justify-center gap-4 py-2">
    <a
      v-for="profile in availableProfiles"
      :key="profile.key"
      :href="`${profile.link}${socialProfiles[profile.key]}`"
      target="_blank"
      rel="noopener noreferrer nofollow"
      class="text-slate-400 hover:text-blue-500 transition-colors"
    >
      <span :class="[profile.icon, 'size-5']" />
    </a>
  </div>
</template>
