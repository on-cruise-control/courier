import { frontendURL } from '../../../helper/URLHelper';
import store from 'dashboard/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import LeadFormsIndex from './pages/LeadFormsIndex.vue';
import FormLeadsIndex from './pages/FormLeadsIndex.vue';

const meta = {
  permissions: ['administrator', 'agent', 'custom_role'],
};

const redirectIfNoFacebookInbox = async (to, from, next) => {
  const { accountId } = to.params;
  if (!store.getters['accounts/getAccount'](accountId).id) {
    await store.dispatch('accounts/get');
  }
  if (!store.getters['inboxes/getInboxes'].length) {
    await store.dispatch('inboxes/get');
  }
  const inboxes = store.getters['inboxes/getInboxes'];
  if (!store.getters['accounts/getAccount'](accountId).id || !inboxes.length) {
    next();
    return;
  }
  const hasFacebookInbox = inboxes.some(
    inbox => inbox.channel_type === 'Channel::FacebookPage'
  );
  const isLeadsEnabled = store.getters['accounts/isFeatureEnabledonAccount'](
    accountId,
    FEATURE_FLAGS.FACEBOOK_LEADS
  );
  next(
    hasFacebookInbox && isLeadsEnabled
      ? undefined
      : frontendURL(`accounts/${accountId}/dashboard`)
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
