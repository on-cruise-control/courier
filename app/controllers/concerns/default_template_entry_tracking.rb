module DefaultTemplateEntryTracking
  private

  def carry_default_markers(old_entry, entry, modified: true)
    return entry unless old_entry&.dig('default_template_id')

    markers = old_entry.slice(*DefaultTemplate::ENTRY_MARKERS)
    markers['locally_modified'] = true if modified
    entry.stringify_keys.merge(markers)
  end

  def exclude_default_template(entry)
    return unless entry&.dig('default_template_id')

    DefaultTemplateExclusion.find_or_create_by!(inbox_id: @inbox.id, default_template_id: entry['default_template_id'])
  end
end
