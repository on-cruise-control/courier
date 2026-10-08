class SuperAdmin::DefaultTemplatesController < SuperAdmin::ApplicationController
  def index
    @props = {
      templates: DefaultTemplate.order(:name).as_json(only: [:id, :name, :platform, :category, :content, :language]),
      settings: DefaultTemplates::Settings.all
    }
  end

  def create
    template = DefaultTemplate.new(template_params)
    save_and_render(template, :created)
  end

  def update
    template = DefaultTemplate.find(params[:id])
    template.assign_attributes(template_params.except(:platform))
    save_and_render(template, :ok)
  end

  def destroy
    DefaultTemplate.find(params[:id]).destroy!
    head :ok
  end

  def upload
    blob = ActiveStorage::Blob.create_and_upload!(
      io: params.require(:attachment).tempfile,
      filename: params[:attachment].original_filename,
      content_type: params[:attachment].content_type
    )
    return render_unsupported_upload(blob) unless allowed_upload_types.include?(blob.content_type)

    # A permanent proxy link built from FRONTEND_URL: reachable by Twilio/Meta (unlike localhost) and without a redirect hop.
    render json: { file_url: Rails.application.routes.url_helpers.rails_storage_proxy_url(blob) }
  end

  def update_settings
    DefaultTemplates::Settings.update(params.permit(*DefaultTemplates::Settings::KEYS.keys).to_h.symbolize_keys)
    render json: { settings: DefaultTemplates::Settings.all }
  end

  private

  # Checked against the real file content, since the declared type comes from the file extension.
  def allowed_upload_types
    images = %w[image/png image/jpeg]
    return images if params[:image_only].present?

    images + %w[video/mp4 video/ogg video/x-msvideo video/quicktime video/webm]
  end

  def render_unsupported_upload(blob)
    detected = blob.content_type
    blob.purge
    render json: { error: "This file is actually #{detected}, which is not supported. Use a real PNG or JPEG image." },
           status: :unprocessable_entity
  end

  def save_and_render(template, status)
    if template.save
      render json: { template: template.as_json(only: [:id, :name, :platform, :category, :content, :language]) }, status: status
    else
      render json: { errors: template.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    # Two identical requests (e.g. a double click) can both pass validation; the unique index catches the second.
    render json: { errors: ['Name has already been taken'] }, status: :unprocessable_entity
  end

  def template_params
    params.require(:template).permit(
      :name, :platform, :category, :language,
      content: [:body, :media_type, :media_url, :caption,
                { items: [:title, :value, :content_type, :text, :description, :media_url,
                          { actions: [:text, :type, :payload, :uri, :title],
                            buttons: [:type, :title, :payload, :uri],
                            default_action: [:type, :url] }] }]
    )
  end
end
