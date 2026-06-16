class Api::V1::Widget::VehiclesController < Api::V1::Widget::BaseController
  include HTTParty

  skip_before_action :set_contact

  def show
    base_url = GlobalConfig.get_value('DEALERSHIP_API_BASE_URL')
    api_key  = GlobalConfig.get_value('DEALERSHIP_API_KEY')

    return render json: { error: 'Dealership API not configured' }, status: :service_unavailable if base_url.blank?

    response = HTTParty.get(
      "#{base_url}/api/v1/vehicles/#{params[:id]}",
      headers: {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'Authorization' => "Bearer #{api_key}"
      },
      timeout: 10
    )

    render json: response.parsed_response, status: response.code
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end
end
