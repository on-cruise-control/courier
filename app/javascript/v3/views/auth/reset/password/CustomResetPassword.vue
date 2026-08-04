<script>
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required, minLength, email } from '@vuelidate/validators';
import { useBranding } from 'shared/composables/useBranding';
import { mapGetters } from 'vuex';
import FormInput from '../../../../components/Form/Input.vue';
import { resetPassword } from '../../../../api/auth';
import Spinner from 'shared/components/Spinner.vue';

export default {
  components: { FormInput, Spinner },
  setup() {
    const { replaceInstallationName } = useBranding();
    return { v$: useVuelidate(), replaceInstallationName };
  },
  data() {
    return {
      credentials: { email: '' },
      resetPassword: { message: '', showLoading: false },
      error: '',
    };
  },
  validations() {
    return {
      credentials: {
        email: { required, email, minLength: minLength(4) },
      },
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
  },
  methods: {
    showAlertMessage(message) {
      this.resetPassword.showLoading = false;
      useAlert(message);
    },
    submit() {
      this.resetPassword.showLoading = true;
      resetPassword(this.credentials)
        .then(res => {
          const successMessage =
            res.data?.message || this.$t('RESET_PASSWORD.API.SUCCESS_MESSAGE');
          this.showAlertMessage(successMessage);
        })
        .catch(error => {
          const errorMessage =
            error?.response?.data?.message || this.$t('RESET_PASSWORD.API.ERROR_MESSAGE');
          this.showAlertMessage(errorMessage);
        });
    },
  },
};
</script>

<template>
  <div class="flex h-screen overflow-hidden w-full font-['Outfit',sans-serif] bg-white dark:bg-n-solid-1">
    <!-- Left panel: form -->
    <div class="flex flex-col w-full lg:w-[48%] px-8 py-4 sm:py-8 lg:px-16 justify-between bg-white dark:bg-n-solid-1 overflow-y-auto">
      <!-- Logo -->
      <div>
        <img
          :src="globalConfig.logo"
          :alt="globalConfig.installationName"
          class="h-9 w-auto dark:hidden"
        />
        <img
          v-if="globalConfig.logoDark"
          :src="globalConfig.logoDark"
          :alt="globalConfig.installationName"
          class="hidden h-9 w-auto dark:block"
        />
      </div>

      <!-- Form area -->
      <div class="flex-1 flex flex-col justify-center max-w-sm mx-auto w-full mt-4 sm:mt-8">
        <div class="mb-4 sm:mb-8">
          <h2 class="text-2xl font-bold text-n-slate-12 leading-tight">
            {{ $t('RESET_PASSWORD.TITLE') }}
          </h2>
          <p class="mt-1.5 text-sm text-n-slate-10 leading-relaxed">
            {{ replaceInstallationName($t('RESET_PASSWORD.DESCRIPTION')) }}
          </p>
        </div>

        <form class="space-y-4" @submit.prevent="submit">
          <FormInput
            v-model="credentials.email"
            name="email_address"
            :has-error="v$.credentials.email.$error"
            :error-message="$t('RESET_PASSWORD.EMAIL.ERROR')"
            :placeholder="$t('RESET_PASSWORD.EMAIL.PLACEHOLDER')"
            @input="v$.credentials.email.$touch"
          />

          <button
            type="submit"
            class="w-full py-3 px-4 rounded-xl text-white text-sm font-semibold transition-all duration-200 disabled:opacity-60 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            style="background-color: #182933;"
            :disabled="v$.credentials.email.$invalid || resetPassword.showLoading"
            data-testid="submit_button"
          >
            <Spinner v-if="resetPassword.showLoading" size="" color-scheme="white" />
            <span v-else>{{ $t('RESET_PASSWORD.SUBMIT') }}</span>
          </button>
        </form>

        <p class="mt-6 text-sm text-center text-n-slate-10">
          {{ $t('RESET_PASSWORD.GO_BACK_TO_LOGIN') }}
          <router-link to="/app/login" class="font-medium" style="color: #182933;">
            {{ $t('COMMON.CLICK_HERE') }}.
          </router-link>
        </p>
      </div>

      <p class="text-xs text-n-slate-9 mt-2">
        © {{ new Date().getFullYear() }} {{ $t('LOGIN.FOOTER') }}
      </p>
    </div>

    <!-- Right panel: orbital illustration -->
    <div
      class="hidden lg:flex lg:flex-1 flex-col justify-between p-12 relative overflow-hidden"
      style="background: radial-gradient(ellipse at 50% 48%, #243f50 0%, #1e3545 30%, #182933 60%, #111f27 100%);"
    >
      <div
        class="absolute inset-0 z-0"
        style="background-image: radial-gradient(circle, rgba(255,255,255,0.05) 1px, transparent 1px); background-size: 30px 30px;"
      />

      <div class="relative z-10 flex-1 flex flex-col items-center justify-center text-center">
        <div class="relative flex items-center justify-center mb-10" style="width: 340px; height: 340px;">
          <div class="absolute rounded-full border" style="width: 320px; height: 320px; border-color: rgb(255 255 255);" />
          <div class="absolute rounded-full border" style="width: 220px; height: 220px; border-color: rgb(255 255 255);" />
          <div class="absolute rounded-full border" style="width: 130px; height: 130px; border-color: rgb(255 255 255);" />

          <!-- Center logo -->
          <div>
            <img :src="'/brand-assets/logo_thumbnail.svg'" alt="Cruise Control" class="w-20 h-20 object-contain" />
          </div>

          <!-- WhatsApp - top -->
          <div class="absolute w-11 h-11 rounded-2xl flex items-center justify-center shadow-lg" style="top: 1px; left: 50%; transform: translateX(-50%); background-color: #25D366;">
            <svg viewBox="0 0 24 24" class="w-6 h-6 fill-white"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>
          </div>
          <!-- Facebook - top-right (1 o'clock) -->
          <div
            class="absolute w-11 h-11 rounded-2xl flex items-center justify-center shadow-lg"
            style="bottom: 140px; right: -5px; background-color: #1877F2;"
          >
            <svg viewBox="0 0 24 24" class="w-6 h-6 fill-white">
              <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
            </svg>
          </div>
          <!-- Instagram - right -->
          <div class="absolute w-11 h-11 rounded-2xl flex items-center justify-center shadow-lg" style="top: 40px; right: 28px; background: linear-gradient(135deg, #f09433 0%, #e6683c 25%, #dc2743 50%, #cc2366 75%, #bc1888 100%);">
            <svg viewBox="0 0 24 24" class="w-6 h-6 fill-white"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z"/></svg>
          </div>
          <!-- Messenger - bottom -->
          <div class="absolute w-11 h-11 rounded-2xl flex items-center justify-center shadow-lg" style="bottom: 1px; left: 50%; transform: translateX(-50%); background: linear-gradient(135deg, #0099FF 0%, #a033ff 100%);">
            <svg viewBox="0 0 24 24" class="w-6 h-6 fill-white"><path d="M12 0C5.373 0 0 4.974 0 11.111c0 3.498 1.744 6.614 4.469 8.652V24l4.088-2.242c1.092.3 2.246.464 3.443.464 6.627 0 12-4.975 12-11.111C24 4.975 18.627 0 12 0zm1.191 14.963l-3.055-3.26-5.963 3.26L10.732 8l3.131 3.259L19.752 8l-6.561 6.963z"/></svg>
          </div>
          <!-- Telegram - left -->
          <div class="absolute w-11 h-11 rounded-2xl flex items-center justify-center shadow-lg" style="top: 52px; left: 24px; background-color: #229ED9;">
            <svg viewBox="0 0 24 24" class="w-6 h-6 fill-white"><path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/></svg>
          </div>
          <!-- Email - bottom-left -->
          <div class="absolute w-10 h-10 rounded-2xl flex items-center justify-center shadow-lg" style="bottom: 62px; left: 18px; background-color: #EA4335;">
            <svg viewBox="0 0 24 24" class="w-5 h-5 fill-white"><path d="M24 5.457v13.909c0 .904-.732 1.636-1.636 1.636h-3.819V11.73L12 16.64l-6.545-4.91v9.273H1.636A1.636 1.636 0 010 19.366V5.457c0-2.023 2.309-3.178 3.927-1.964L5.455 4.64 12 9.548l6.545-4.91 1.528-1.145C21.69 2.28 24 3.434 24 5.457z"/></svg>
          </div>
          <!-- LINE - top-left -->
          <div class="absolute w-10 h-10 rounded-2xl flex items-center justify-center shadow-lg" style="left: 42px; top: 50%; transform: translateY(-50%); background-color: #06C755;">
            <svg viewBox="0 0 24 24" class="w-5 h-5 fill-white"><path d="M19.365 9.863c.349 0 .63.285.63.631 0 .345-.281.63-.63.63H17.61v1.125h1.755c.349 0 .63.283.63.63 0 .344-.281.629-.63.629h-2.386c-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.627-.63h2.386c.349 0 .63.285.63.63 0 .349-.281.63-.63.63H17.61v1.125h1.755zm-3.855 3.016c0 .27-.174.51-.432.596-.064.021-.133.031-.199.031-.211 0-.391-.09-.51-.25l-2.443-3.317v2.94c0 .344-.279.629-.631.629-.346 0-.626-.285-.626-.629V8.108c0-.27.173-.51.43-.595.06-.023.136-.033.194-.033.195 0 .375.104.495.254l2.462 3.33V8.108c0-.345.282-.63.63-.63.345 0 .63.285.63.63v4.771zm-5.741 0c0 .344-.282.629-.631.629-.345 0-.627-.285-.627-.629V8.108c0-.345.282-.63.627-.63.349 0 .631.285.631.63v4.771zm-2.466.629H4.917c-.345 0-.63-.285-.63-.629V8.108c0-.345.285-.63.63-.63.348 0 .63.285.63.63v4.141h1.756c.348 0 .629.283.629.63 0 .344-.281.629-.629.629M24 10.314C24 4.943 18.615.572 12 .572S0 4.943 0 10.314c0 4.811 4.27 8.842 10.035 9.608.391.082.923.258 1.058.59.12.301.079.766.038 1.08l-.164 1.02c-.045.301-.24 1.186 1.049.645 1.291-.539 6.916-4.078 9.436-6.975C23.176 14.393 24 12.458 24 10.314"/></svg>
          </div>
          <!-- SMS - bottom-right -->
          <div class="absolute w-10 h-10 rounded-2xl flex items-center justify-center shadow-lg" style="top: 85px; right: 129px; background-color: #5865F2;">
            <svg viewBox="0 0 24 24" class="w-5 h-5 fill-white"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-3 9H7V9h10v2zm0-3H7V6h10v2z"/></svg>
          </div>
           <!-- TikTok - outer ring, bottom-right diagonal -->
          <div
            class="absolute w-11 h-11 rounded-2xl flex items-center justify-center shadow-lg"
            style="bottom: 80px; right: 60px; background-color: #010101;"
          >
            <svg viewBox="0 0 24 24" class="w-5 h-5 fill-white">
              <path d="M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z"/>
            </svg>
            <span
              class="absolute -top-[-1px] -right-0.5 text-white font-semibold rounded-full px-1 py-px leading-none"
              style="font-size: 7px; background-color: #FE2C55;"
            >Soon</span>
          </div>
        </div>

        <h1 class="text-3xl font-bold leading-tight mb-3 text-white">
          {{ $t('LOGIN.CONNTECT_BATTER') }}<br />{{ $t('LOGIN.SELL_SMARTER') }}
        </h1>
        <p class="text-sm leading-relaxed max-w-xs" style="color: rgba(255,255,255,0.55);">
          {{ $t('LOGIN.TEXT') }}
        </p>
        <div class="flex flex-wrap gap-2 justify-center mt-6">
          <span v-for="feature in ['AI-Powered', 'Multi-Channel', 'Real-Time', 'Auto Responses']" :key="feature" class="px-3 py-1 rounded-full text-xs font-semibold" style="background-color: rgba(255,255,255,0.12); color: rgba(255,255,255,0.8);">{{ feature }}</span>
        </div>
      </div>

      <p class="relative z-10 text-xs text-center" style="color: rgba(255,255,255,0.3);">
        © {{ new Date().getFullYear() }} {{ $t('LOGIN.FOOTER') }}
      </p>
    </div>
  </div>
</template>
