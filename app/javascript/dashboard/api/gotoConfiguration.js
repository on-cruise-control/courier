/* global axios */
import ApiClient from './ApiClient';

class GotoConfigurationAPI extends ApiClient {
  constructor() {
    super('goto_configuration', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  authorization() {
    return axios.post(`${this.url}/authorization`);
  }

  lines() {
    return axios.get(`${this.url}/lines`);
  }

  update(data) {
    return axios.put(this.url, data);
  }

  delete() {
    return axios.delete(this.url);
  }
}

export default new GotoConfigurationAPI();
