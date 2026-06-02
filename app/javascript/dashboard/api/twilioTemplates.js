import ApiClient from './ApiClient';

class TwilioTemplatesApi extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  list(inboxId) {
    return window.axios.get(`${this.url}/${inboxId}/twilio_templates`);
  }

  create(inboxId, template) {
    return window.axios.post(`${this.url}/${inboxId}/twilio_templates`, {
      template,
    });
  }

  update(inboxId, contentSid, template) {
    return window.axios.put(
      `${this.url}/${inboxId}/twilio_templates/${contentSid}`,
      { template }
    );
  }

  delete(inboxId, contentSid) {
    return window.axios.delete(
      `${this.url}/${inboxId}/twilio_templates/${contentSid}`
    );
  }

  submitApproval(inboxId, contentSid, { name, category }) {
    return window.axios.post(
      `${this.url}/${inboxId}/twilio_templates/${contentSid}/submit_approval`,
      { name, category }
    );
  }

  sync(inboxId) {
    return window.axios.post(`${this.url}/${inboxId}/twilio_templates/sync`);
  }
}

export default new TwilioTemplatesApi();
