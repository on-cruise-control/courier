import types from '../mutation-types';
import ConversationApi from '../../api/inbox/conversation';
import { debounce } from '@chatwoot/utils';

const state = {
  mineCount: 0,
  unAssignedCount: 0,
  allCount: 0,
  commentsCount: 0,
  updatedOn: null,
};

export const getters = {
  getStats: (state) => state,
};

// Create a debounced version of the actual API call function
const fetchMetaData = async (commit, params) => {
  try {
    const response = await ConversationApi.meta(params);
    const {
      data: { meta },
    } = response;
    commit(types.SET_CONV_TAB_META, meta);
  } catch (error) {
    // ignore
  }
};

const debouncedFetchMetaData = debounce(fetchMetaData, 500, false, 2000);
const longDebouncedFetchMetaData = debounce(fetchMetaData, 5000, false, 10000);
const superLongDebouncedFetchMetaData = debounce(
  fetchMetaData,
  10000,
  false,
  20000
);

export const actions = {
  get: async ({ commit, state: $state }, params) => {
    if ($state.allCount > 2000) {
      superLongDebouncedFetchMetaData(commit, params);
    } else if ($state.allCount > 100) {
      longDebouncedFetchMetaData(commit, params);
    } else {
      debouncedFetchMetaData(commit, params);
    }
  },

  set({ commit }, meta) {
    commit(types.SET_CONV_TAB_META, meta);
  },
};

export const mutations = {
  [types.SET_CONV_TAB_META](
    state,
    {
      mine_count: mineCount = 0,
      unassigned_count: unAssignedCount = 0,
      all_count: allCount = 0,
      comments_count: commentsCount = 0,
    } = {}
  ) {
    state.mineCount = mineCount;
    state.allCount = allCount;
    state.unAssignedCount = unAssignedCount;
    state.commentsCount = commentsCount;
    state.updatedOn = new Date();
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
