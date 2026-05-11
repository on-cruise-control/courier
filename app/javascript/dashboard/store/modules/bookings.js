import BookingsAPI from '../../api/bookings';
import { downloadCsvFile } from '../../helper/downloadHelper';

const state = {
    records: [],
    uiFlags: {
        isFetching: false,
        isError: false,
    },
    meta: {
        count: 0,
        currentPage: 1,
    },
};

const getters = {
    getRecords(_state) {
        return _state.records;
    },
    getRecordById: _state => id => {
        return _state.records.find(record => record.id === id);
    },
    getUIFlags(_state) {
        return _state.uiFlags;
    },
    getMeta(_state) {
        return _state.meta;
    },
};

const actions = {
  fetch: async ({ commit }, params) => {
    commit('SET_UI_FLAGS', { isFetching: true, isError: false });
    try {
      const response = await BookingsAPI.get(params);
      commit('SET_RECORDS', response.data.results);
      commit('SET_META', {
        count: response.data.count,
        currentPage: params.page || 1,
      });
      commit('SET_UI_FLAGS', { isFetching: false, isError: false });
    } catch (error) {
      commit('SET_UI_FLAGS', { isFetching: false, isError: true });
      throw error;
    }
  },
  download: async (_, params) => {
    const response = await BookingsAPI.download(params);
    const exportData = response.data?.data ?? response.data;
    const exportUrl =
      typeof exportData === 'string'
        ? exportData
        : exportData?.url || exportData?.file_url;

    if (typeof exportUrl === 'string' && /^https?:\/\//.test(exportUrl)) {
      const link = document.createElement('a');
      link.setAttribute('href', exportUrl);
      link.setAttribute('download', params.fileName);
      link.click();
      return exportUrl;
    }

    downloadCsvFile(params.fileName, exportData);
    return exportData;
  },
  show: async ({ commit }, id) => {
    commit('SET_UI_FLAGS', { isFetching: true, isError: false });
    try {
      const response = await BookingsAPI.show(id);
      commit('SET_UI_FLAGS', { isFetching: false, isError: false });
      return response.data;
    } catch (error) {
      commit('SET_UI_FLAGS', { isFetching: false, isError: true });
      throw error;
    }
  },
};

const mutations = {
  SET_RECORDS(_state, records) {
    _state.records = records;
  },
  SET_UI_FLAGS(_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  SET_META(_state, meta) {
    _state.meta = { ..._state.meta, ...meta };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
