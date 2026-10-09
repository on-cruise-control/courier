/* global axios */
import ApiClient from './ApiClient';

class FacebookLeadsAPI extends ApiClient {
  constructor() {
    super('facebook_leads', { accountScoped: true });
  }

  getPages() {
    return axios.get(`${this.url}/pages`);
  }

  sync(inboxId) {
    return axios.post(`${this.url}/sync`, { inbox_id: inboxId });
  }

  getLeads({ inboxId, formId, page, q }) {
    return axios.get(this.url, {
      params: { inbox_id: inboxId, form_id: formId, page, q },
    });
  }
}

export default new FacebookLeadsAPI();
