import { frontendURL } from '../../../helper/URLHelper';
import BookingsList from './pages/BookingsList.vue';
import BookingDetails from './pages/BookingDetails.vue';

const routes = [
    {
        path: frontendURL('accounts/:accountId/bookings'),
        name: 'bookings_index',
        meta: {
            permissions: ['administrator', 'agent', 'custom_role'],
        },
        component: BookingsList,
    },
    {
        path: frontendURL('accounts/:accountId/bookings/:bookingId'),
        name: 'bookings_details',
        meta: {
            permissions: ['administrator', 'agent', 'custom_role'],
        },
        component: BookingDetails,
    },
];

export default {
    routes,
};
