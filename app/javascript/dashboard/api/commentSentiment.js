/* global axios */
import ApiClient from './ApiClient';

class CommentSentimentAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  updateSentiment(conversationId, reason = null) {
    return axios.post(`${this.url}/${conversationId}/update_comment_sentiment`, {
      reason,
    });
  }
}

export default new CommentSentimentAPI();
