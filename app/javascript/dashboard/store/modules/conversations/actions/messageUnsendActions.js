import MessageApi from '../../../../api/inbox/message';

export default {
  unsendMessage: async function unsendMessage(
    _,
    { conversationId, messageId }
  ) {
    try {
      await MessageApi.unsend(conversationId, messageId);
      return true;
    } catch (error) {
      throw new Error('CONVERSATION.CONTEXT_MENU.FAIL_UNSEND_MESSAGE');
    }
  },
};
