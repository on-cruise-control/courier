import OffersAPI from '../../api/offers';

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

const getters = {
  getRecords(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

const actions = {
  fetch: async ({ commit }) => {
    commit('SET_UI_FLAGS', { isFetching: true });
    try {
      const response = await OffersAPI.get();
      commit('SET_RECORDS', response.data.results || []);
    } finally {
      commit('SET_UI_FLAGS', { isFetching: false });
    }
  },
  create: async ({ commit }, offer) => {
    commit('SET_UI_FLAGS', { isCreating: true });
    try {
      const response = await OffersAPI.create(offer);
      commit('ADD_RECORD', response.data);
      return response.data;
    } finally {
      commit('SET_UI_FLAGS', { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...offer }) => {
    commit('SET_UI_FLAGS', { isUpdating: true });
    try {
      const response = await OffersAPI.update(id, offer);
      commit('EDIT_RECORD', { id, offer: response.data });
      return response.data;
    } finally {
      commit('SET_UI_FLAGS', { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit('SET_UI_FLAGS', { isDeleting: true });
    try {
      await OffersAPI.delete(id);
      commit('REMOVE_RECORD', id);
    } finally {
      commit('SET_UI_FLAGS', { isDeleting: false });
    }
  },
};

const mutations = {
  SET_RECORDS(_state, records) {
    _state.records = records;
  },
  ADD_RECORD(_state, record) {
    _state.records.push(record);
  },
  EDIT_RECORD(_state, { id, offer }) {
    const index = _state.records.findIndex(record => record.id === id);
    if (index !== -1) {
      _state.records.splice(index, 1, offer);
    }
  },
  REMOVE_RECORD(_state, id) {
    _state.records = _state.records.filter(record => record.id !== id);
  },
  SET_UI_FLAGS(_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
