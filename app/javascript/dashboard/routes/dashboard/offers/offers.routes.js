import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { frontendURL } from '../../../helper/URLHelper';
import OffersList from './pages/OffersList.vue';

const meta = {
  permissions: ['administrator', 'agent', 'custom_role'],
  featureFlag: FEATURE_FLAGS.OFFERS_AND_PROMOTIONS,
};

const routes = [
  {
    path: frontendURL('accounts/:accountId/offers'),
    name: 'offers_index',
    meta,
    component: OffersList,
  },
];

export default {
  routes,
};
