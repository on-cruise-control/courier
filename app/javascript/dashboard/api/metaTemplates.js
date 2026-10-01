import ApiClient from './ApiClient';

class MetaTemplatesApi extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  list(inboxId) {
    return window.axios.get(`${this.url}/${inboxId}/meta_templates`);
  }

  create(inboxId, template) {
    return window.axios.post(`${this.url}/${inboxId}/meta_templates`, {
      template,
    });
  }

  update(inboxId, templateId, template) {
    return window.axios.put(
      `${this.url}/${inboxId}/meta_templates/${templateId}`,
      { template }
    );
  }

  delete(inboxId, templateId) {
    return window.axios.delete(
      `${this.url}/${inboxId}/meta_templates/${templateId}`
    );
  }
}

export default new MetaTemplatesApi();
