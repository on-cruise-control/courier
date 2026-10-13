# frozen_string_literal: true

class Api::V1::Accounts::OffersController < Api::V1::Accounts::BaseController
  def index
    service = Offers::OfferService.new(current_account.dealership_id)
    render_offer_result(service.fetch_offers)
  end

  def create
    return render_offer_result(document_and_source_url_error) if document_and_source_url_present?

    service = Offers::OfferService.new(current_account.dealership_id)
    render_offer_result(service.create_offer(offer_params))
  end

  def update
    return render_offer_result(document_and_source_url_error) if document_and_source_url_present?

    service = Offers::OfferService.new(current_account.dealership_id)
    render_offer_result(service.update_offer(params[:id], offer_params))
  end

  def destroy
    service = Offers::OfferService.new(current_account.dealership_id)
    render_offer_result(service.delete_offer(params[:id]))
  end

  private

  def render_offer_result(result)
    if result[:error]
      render json: { error: result[:error] }, status: result[:status] || 500
    else
      render json: result
    end
  end

  def offer_params
    params.permit(:title, :start_date, :end_date, :offer_document, :source_url, :remove_offer_document)
  end

  def document_and_source_url_present?
    offer_params[:offer_document].present? && offer_params[:source_url].present?
  end

  def document_and_source_url_error
    { error: 'An offer can have either a document or a source URL, but not both', status: 422 }
  end
end
