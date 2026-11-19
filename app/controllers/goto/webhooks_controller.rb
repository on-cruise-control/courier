class Goto::WebhooksController < ActionController::API
  def create
    Webhooks::GotoEventsJob.perform_later(params[:token], params.to_unsafe_h.deep_symbolize_keys)

    head :ok
  end

  # GoTo sends OPTIONS to verify the URL when the notification channel is created.
  def verify
    response.set_header('Allow', 'POST, OPTIONS')
    head :ok
  end
end
