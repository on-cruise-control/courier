import { frontendURL } from '../../../helper/URLHelper';
import store from 'dashboard/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import LeadFormsIndex from './pages/LeadFormsIndex.vue';
import FormLeadsIndex from './pages/FormLeadsIndex.vue';

const meta = {
  permissions: ['administrator', 'agent', 'custom_role'],
};

const redirectIfNoFacebookInbox = async (to, from, next) => {
  if (!store.getters['inboxes/getInboxes'].length) {
    await store.dispatch('inboxes/get');
  }
  const hasFacebookInbox = store.getters['inboxes/getInboxes'].some(
    inbox => inbox.channel_type === 'Channel::FacebookPage'
  );
  const isLeadsEnabled = store.getters['accounts/isFeatureEnabledonAccount'](
    to.params.accountId,
    FEATURE_FLAGS.FACEBOOK_LEADS
  );
  next(
    hasFacebookInbox && isLeadsEnabled
      ? undefined
      : frontendURL(`accounts/${to.params.accountId}/dashboard`)
  );
};

const routes = [
  {
    path: frontendURL('accounts/:accountId/leads'),
    name: 'facebook_lead_forms_index',
    meta,
    beforeEnter: redirectIfNoFacebookInbox,
    component: LeadFormsIndex,
  },
  {
    path: frontendURL('accounts/:accountId/leads/forms/:formId'),
    name: 'facebook_form_leads_index',
    meta,
    beforeEnter: redirectIfNoFacebookInbox,
    component: FormLeadsIndex,
  },
];

export default {
  routes,
};
