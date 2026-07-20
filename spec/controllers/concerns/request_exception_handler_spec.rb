require 'rails_helper'

# Create a test controller that includes the concern
class TestExceptionController < ActionController::Base
  include RequestExceptionHandler

  def test_render_unauthorized
    render_unauthorized('Not allowed')
  end

  def test_render_not_found_error
    render_not_found_error('Not found')
  end

  def test_render_could_not_create_error
    render_could_not_create_error('Could not create')
  end

  def test_render_payment_required
    render_payment_required('Payment needed')
  end

  def test_render_internal_server_error
    render_internal_server_error('Server error')
  end

  def test_handle_record_not_found
    handle_with_exception { raise ActiveRecord::RecordNotFound }
  end

  def test_handle_not_authorized
    handle_with_exception { raise Pundit::NotAuthorizedError }
  end

  def test_handle_parameter_missing
    handle_with_exception { raise ActionController::ParameterMissing, :param_name }
  end
end

RSpec.describe TestExceptionController, type: :controller do
  before do
    # `routes` here is Rails.application.routes itself (not an isolated set),
    # so `.draw` below clears and replaces every real app route with just the
    # test routes below. Without restoring it afterwards, every other spec
    # that runs later in this process (e.g. dashboard_controller_spec.rb)
    # gets 404s because the real routes never come back.
    routes.draw do
      get 'test_render_unauthorized', to: 'test_exception#test_render_unauthorized'
      get 'test_render_not_found_error', to: 'test_exception#test_render_not_found_error'
      get 'test_render_could_not_create_error', to: 'test_exception#test_render_could_not_create_error'
      get 'test_render_payment_required', to: 'test_exception#test_render_payment_required'
      get 'test_render_internal_server_error', to: 'test_exception#test_render_internal_server_error'
      get 'test_handle_record_not_found', to: 'test_exception#test_handle_record_not_found'
      get 'test_handle_not_authorized', to: 'test_exception#test_handle_not_authorized'
      get 'test_handle_parameter_missing', to: 'test_exception#test_handle_parameter_missing'
    end
    allow(controller).to receive(:logger).and_return(Logger.new(nil))
  end

  after do
    Rails.application.reload_routes!
  end

  describe '#render_unauthorized' do
    it 'returns unauthorized status with error message' do
      get :test_render_unauthorized
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['error']).to eq('Not allowed')
    end
  end

  describe '#render_not_found_error' do
    it 'returns not_found status with error message' do
      get :test_render_not_found_error
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Not found')
    end
  end

  describe '#render_could_not_create_error' do
    it 'returns unprocessable_entity status with error message' do
      get :test_render_could_not_create_error
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to eq('Could not create')
    end
  end

  describe '#render_payment_required' do
    it 'returns payment_required status with error message' do
      get :test_render_payment_required
      expect(response).to have_http_status(:payment_required)
      expect(JSON.parse(response.body)['error']).to eq('Payment needed')
    end
  end

  describe '#render_internal_server_error' do
    it 'returns internal_server_error status with error message' do
      get :test_render_internal_server_error
      expect(response).to have_http_status(:internal_server_error)
      expect(JSON.parse(response.body)['error']).to eq('Server error')
    end
  end

  describe '#handle_with_exception' do
    it 'rescues ActiveRecord::RecordNotFound' do
      get :test_handle_record_not_found
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Resource could not be found')
    end

    it 'rescues Pundit::NotAuthorizedError' do
      get :test_handle_not_authorized
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['error']).to eq('You are not authorized to do this action')
    end

    it 'rescues ActionController::ParameterMissing' do
      get :test_handle_parameter_missing
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to eq('param is missing or the value is empty: param_name')
    end
  end
end
