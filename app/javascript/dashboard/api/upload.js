import ApiClient from './ApiClient';

class UploadApi extends ApiClient {
  constructor() {
    super('upload', { accountScoped: true });
  }

  createFromFile(file) {
    const formData = new FormData();
    formData.append('attachment', file);
    return this.create(formData);
  }
}

export default new UploadApi();
