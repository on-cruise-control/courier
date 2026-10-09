import { frontendURL } from '../../../helper/URLHelper';
import LeadFormsIndex from './pages/LeadFormsIndex.vue';
import FormLeadsIndex from './pages/FormLeadsIndex.vue';

const meta = {
  permissions: ['administrator', 'agent', 'custom_role'],
};

const routes = [
  {
    path: frontendURL('accounts/:accountId/leads'),
    name: 'facebook_lead_forms_index',
    meta,
    component: LeadFormsIndex,
  },
  {
    path: frontendURL('accounts/:accountId/leads/forms/:formId'),
    name: 'facebook_form_leads_index',
    meta,
    component: FormLeadsIndex,
  },
];

export default {
  routes,
};
