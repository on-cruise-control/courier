class InboxDrop < BaseDrop
  def name
    @obj.try(:name)
  end

  def platform_name
    @obj.try(:platform_name)
  end
end
