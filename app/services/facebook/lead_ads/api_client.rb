# ref https://developers.facebook.com/docs/marketing-api/guides/lead-ads/retrieving
class Facebook::LeadAds::ApiClient
  FORM_FIELDS = 'id,name,status,locale,leads_count,questions,created_time'.freeze
  LEAD_FIELDS = 'id,created_time,field_data,ad_id,ad_name,adset_id,adset_name,campaign_id,campaign_name,form_id,platform,is_organic'.freeze

  def initialize(channel)
    @channel = channel
    @graph = Koala::Facebook::API.new(channel.page_access_token)
  end

  def page_name
    @graph.get_object(@channel.page_id, fields: 'name')['name']
  end

  def lead_forms
    all_pages(@graph.get_connections(@channel.page_id, 'leadgen_forms', fields: FORM_FIELDS, limit: 100))
  end

  def lead_form(form_id)
    @graph.get_object(form_id, fields: FORM_FIELDS)
  end

  def leads(form_id, since: nil)
    options = { fields: LEAD_FIELDS, limit: 100 }
    options[:filtering] = [{ field: 'time_created', operator: 'GREATER_THAN', value: since.to_i }].to_json if since
    all_pages(@graph.get_connections(form_id, 'leads', options))
  end

  def lead(leadgen_id)
    @graph.get_object(leadgen_id, fields: LEAD_FIELDS)
  end

  private

  def all_pages(collection)
    records = []
    while collection
      records.concat(collection)
      collection = collection.next_page
    end
    records
  end
end
