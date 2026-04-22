/* global axios */
import ApiClient from './ApiClient';

class BookingsAPI extends ApiClient {
    constructor() {
        super('bookings', { accountScoped: true });
    }

    get({ page = 1, pageSize = 10, createdAtAfter, createdAtBefore } = {}) {
        return axios.get(this.url, {
            params: {
                page,
                page_size: pageSize,
                created_at_after: createdAtAfter,
                created_at_before: createdAtBefore,
            },
        });
    }

    show(id) {
        return axios.get(`${this.url}/${id}`);
    }
}

export default new BookingsAPI();
