import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { frontendURL } from '../../../helper/URLHelper';
import BookingsList from './pages/BookingsList.vue';
import BookingDetails from './pages/BookingDetails.vue';

const meta = {
  permissions: ['administrator', 'agent', 'custom_role'],
  featureFlag: FEATURE_FLAGS.BOOKINGS,
};

const routes = [
    {
        path: frontendURL('accounts/:accountId/bookings'),
        name: 'bookings_index',
        meta,
        component: BookingsList,
    },
    {
        path: frontendURL('accounts/:accountId/bookings/:bookingId'),
        name: 'bookings_details',
        meta,
        component: BookingDetails,
    },
];

export default {
    routes,
};
