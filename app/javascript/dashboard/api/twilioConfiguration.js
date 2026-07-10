/* global axios */
import ApiClient from './ApiClient';

class TwilioConfigurationAPI extends ApiClient {
  constructor() {
    super('twilio_configuration', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(data) {
    return axios.post(this.url, { twilio_configuration: data });
  }

  update(data) {
    return axios.put(this.url, { twilio_configuration: data });
  }

  delete() {
    return axios.delete(this.url);
  }
}

export default new TwilioConfigurationAPI();
