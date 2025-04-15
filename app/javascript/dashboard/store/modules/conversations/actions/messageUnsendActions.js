import types from '../../../mutation-types';
import MessageApi from '../../../../api/inbox/message';

export default {
  unsendMessage: async function unsendMessage(
    { commit },
    { conversationId, messageId }
  ) {
    try {
      await MessageApi.unsend(conversationId, messageId);
      commit(types.UPDATE_MESSAGE_STATUS, {
        id: messageId,
        content_attributes: { hidden_from_sender: true },
      });
    } catch (error) {
      throw new Error(error);
    }
  },
};
