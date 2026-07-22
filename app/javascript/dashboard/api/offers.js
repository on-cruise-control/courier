/* global axios */
import ApiClient from './ApiClient';

const buildFormData = ({
  title,
  start_date: startDate,
  end_date: endDate,
  offer_document: offerDocument,
}) => {
  const formData = new FormData();
  if (title !== undefined) formData.append('title', title);
  if (startDate !== undefined) formData.append('start_date', startDate);
  if (endDate !== undefined) formData.append('end_date', endDate);
  if (offerDocument) formData.append('offer_document', offerDocument);
  return formData;
};

class OffersAPI extends ApiClient {
  constructor() {
    super('offers', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(offer) {
    return axios.post(this.url, buildFormData(offer), {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  update(id, offer) {
    return axios.put(`${this.url}/${id}`, buildFormData(offer), {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new OffersAPI();
