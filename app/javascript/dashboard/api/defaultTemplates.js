import ApiClient from './ApiClient';

class DefaultTemplatesApi extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  sync(inboxId) {
    return window.axios.post(`${this.url}/${inboxId}/default_templates/sync`);
  }
}

export default new DefaultTemplatesApi();
