class AddContentTemplatesToFacebookAndInstagramChannels < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_facebook_pages, :content_templates, :jsonb, default: {}
    add_column :channel_instagram, :content_templates, :jsonb, default: {}
  end
end
