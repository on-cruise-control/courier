/* global axios */
import ApiClient from '../ApiClient';

class GotoChannel extends ApiClient {
  constructor() {
    super('channels/goto_channels', { accountScoped: true });
  }

  authorization() {
    return axios.post(`${this.url}/authorization`);
  }

  lines(channelId) {
    return axios.get(`${this.url}/${channelId}/lines`);
  }

  createInbox(channelId, payload) {
    return axios.put(`${this.url}/${channelId}`, payload);
  }
}

export default new GotoChannel();
