class DefaultTemplates::SyncService
  # Lower is better; the copy to keep when a default exists more than once.
  STATUS_RANK = { 'approved' => 0, 'pending' => 1, 'received' => 1 }.freeze

  LOCK_TIMEOUT = 5.minutes.to_i

  pattr_initialize [:inbox!]

  def perform
    return true if platform.blank?

    lock_manager = Redis::LockManager.new
    return false unless lock_manager.lock(lock_key, LOCK_TIMEOUT)

    begin
      reconcile
    ensure
      lock_manager.unlock(lock_key)
    end
    true
  end

  private

  def lock_key
    "DEFAULT_TEMPLATES_SYNC::#{inbox.id}"
  end

  def reconcile
    refresh_from_twilio
    @entries = cached_entries
    remove_orphans
    remove_duplicates
    DefaultTemplate.where(platform: [platform, 'all']).find_each { |default_template| sync(default_template) }
  ensure
    persist if @entries
  end

  def platform
    @platform ||= DefaultTemplate.platform_for(inbox)
  end

  def channel
    inbox.channel
  end

  def twilio?
    platform == 'whatsapp'
  end

  def cached_entries
    channel.content_templates&.dig('templates')&.map(&:dup) || []
  end

  def persist
    attrs = { content_templates: { templates: @entries } }
    attrs[:content_templates_last_updated] = Time.current if twilio?
    channel.update!(attrs)
  end

  def remove_orphans
    live_ids = DefaultTemplate.pluck(:id)
    @entries.select { |e| e['default_template_id'] && live_ids.exclude?(e['default_template_id']) }.each do |entry|
      remove(entry)
    rescue StandardError => e
      Rails.logger.error("Default template removal failed for inbox #{inbox.id}: #{e.message}")
    end
  end

  # Twilio is the source of truth, so its templates are re-read first to avoid creating duplicates from a stale cache.
  def refresh_from_twilio
    return unless twilio?

    Twilio::TemplateSyncService.new(channel: channel).call
    channel.reload
  end

  # The same default can end up twice (e.g. inboxes sharing one Twilio account); only one copy is kept.
  def remove_duplicates
    @entries.select { |e| e['default_template_id'] }.group_by { |e| e['default_template_id'] }.each_value do |copies|
      keeper = copies.min_by { |e| [STATUS_RANK.fetch(e['status'].to_s, 2), e['created_at'].to_s] }
      (copies - [keeper]).each do |duplicate|
        remove(duplicate)
      rescue StandardError => e
        Rails.logger.error("Default template duplicate removal failed for inbox #{inbox.id}: #{e.message}")
      end
    end
  end

  def sync(default_template)
    entry = @entries.find { |e| e['default_template_id'] == default_template.id }
    if entry
      replace(entry, default_template) if outdated?(entry, default_template)
    elsif excluded?(default_template)
      nil
    elsif (unlinked = unlinked_entry_named(default_template))
      unlinked.merge!(default_template.entry_markers)
    else
      add(default_template)
    end
  rescue StandardError => e
    Rails.logger.error("Default template sync failed for inbox #{inbox.id}, template #{default_template.id}: #{e.message}")
  end

  def outdated?(entry, default_template)
    !entry['locally_modified'] && entry['default_version'] != default_template.updated_at.iso8601(6)
  end

  def excluded?(default_template)
    DefaultTemplateExclusion.exists?(inbox_id: inbox.id, default_template_id: default_template.id)
  end

  # An existing template with the same name is linked to the default instead of being created again.
  def unlinked_entry_named(default_template)
    @entries.find { |e| e['default_template_id'].nil? && (e['friendly_name'] || e['name']).to_s.casecmp?(default_template.name) }
  end

  def add(default_template)
    @entries << build_entry(default_template)
  end

  def replace(entry, default_template)
    twilio_service.delete_template(entry['content_sid']) if twilio?
    index = @entries.index(entry)
    @entries[index] = build_entry(default_template)
  end

  def remove(entry)
    twilio_service.delete_template(entry['content_sid']) if twilio?
    @entries.delete(entry)
  end

  def build_entry(default_template)
    (twilio? ? twilio_entry(default_template) : meta_entry(default_template)).merge(default_template.entry_markers)
  end

  def meta_entry(default_template)
    {
      'id' => SecureRandom.uuid,
      'name' => default_template.name,
      'category' => default_template.category,
      'content' => default_template.content,
      'updated_at' => Time.current
    }
  end

  def twilio_entry(default_template)
    params = DefaultTemplates::TwilioParams.new(default_template).to_h
    result = twilio_service.create_template(**params)
    {
      'content_sid' => result['sid'],
      'friendly_name' => result['friendly_name'],
      'language' => result['language'],
      'status' => submit_for_approval(result['sid'], default_template.name),
      'template_type' => default_template.category,
      'media_type' => default_template.content['media_type'],
      'body' => params[:body],
      'variables' => result['variables'] || {},
      'types' => result['types'],
      'created_at' => result['date_created'],
      'updated_at' => result['date_updated']
    }
  end

  # An approval failure keeps the template so the account admin can still submit it manually.
  def submit_for_approval(content_sid, name)
    twilio_service.submit_for_whatsapp_approval(content_sid, name: name, category: 'UTILITY')
    'pending'
  rescue StandardError => e
    Rails.logger.error("Default template approval failed for inbox #{inbox.id}, #{content_sid}: #{e.message}")
    'unsubmitted'
  end

  def twilio_service
    @twilio_service ||= Twilio::TemplateManagementService.new(channel: channel)
  end
end
