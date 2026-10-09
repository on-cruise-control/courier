<script setup>
// Same frame as ContactsListLayout: sticky header, scrolling content, sticky footer
defineProps({
  headerTitle: { type: String, default: '' },
});
</script>

<template>
  <section
    class="flex w-full h-full gap-4 overflow-hidden justify-evenly bg-n-surface-1"
  >
    <div class="flex flex-col w-full h-full">
      <header class="sticky top-0 z-20 px-6">
        <div
          class="flex flex-col sm:flex-row items-start sm:items-center justify-between w-full py-6 gap-4 mx-auto max-w-5xl"
        >
          <slot name="title">
            <span class="text-xl font-medium truncate text-n-slate-12">
              {{ headerTitle }}
            </span>
          </slot>
          <div class="flex flex-wrap items-center gap-2">
            <slot name="actions" />
          </div>
        </div>
      </header>
      <main class="flex-1 overflow-y-auto px-6">
        <div class="w-full mx-auto max-w-5xl pb-6">
          <slot />
        </div>
      </main>
      <footer class="sticky bottom-0 z-0 bg-n-surface-1">
        <slot name="footer" />
      </footer>
    </div>
  </section>
</template>
