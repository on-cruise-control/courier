class SuperAdmin::DealerMetricsService
  CRUISE_DEMO_DEALERSHIP_ID = ENV['CRUISE_DEMO_DEALERSHIP_ID'] || 'CRUISE_DEMO'
  HANDOFF_LABEL = 'handoff'.freeze
  ESCALATION_LABEL = 'escalation'.freeze
  SECTION_KEYS = %w[conversations spam bookings escalations handoffs agent_sessions].freeze
  RANGE_KEYS = %w[last_7_days last_14_days last_30_days last_90_days custom].freeze

  def initialize(dealership_id: nil, account_id: nil, user_id: nil, range_key: 'last_7_days', since:, until_time:)
    @dealership_id = dealership_id.presence
    @account_id = account_id.presence
    @user_id = user_id.presence
    @range_key = RANGE_KEYS.include?(range_key) ? range_key : 'custom'
    @since = since.beginning_of_day
    @until_time = until_time.end_of_day
  end

  def perform(section: nil)
    return initial_payload if section.blank?

    section_payload(section)
  end

  private

  attr_reader :dealership_id, :account_id, :user_id, :range_key, :since, :until_time

  def initial_payload
    {
      filters: filters_payload,
      sections: SECTION_KEYS
    }
  end

  def section_payload(section)
    case section
    when 'conversations'
      conversations_section_payload
    when 'spam'
      spam_section_payload
    when 'bookings'
      bookings_section_payload
    when 'escalations'
      escalations_section_payload
    when 'handoffs'
      handoffs_section_payload
    when 'agent_sessions'
      agent_sessions_section_payload
    else
      conversations_section_payload
    end
  end

  def filters_payload
    {
      selectedDealershipId: dealership_id,
      selectedAccountId: account_id,
      selectedUserId: user_id,
      selectedRangeKey: range_key,
      since: since.to_date.iso8601,
      until: until_time.to_date.iso8601,
      dealerships: all_accounts.map do |account|
        {
          id: account.dealership_id,
          name: account.name
        }
      end
    }
  end

  def conversations_section_payload
    conversation_total = total_conversations
    message_total = total_messages
    average_messages = average(message_total, conversation_total)

    {
      key: 'conversations',
      title: 'Conversations',
      chartSummaryValues: {
        'Conversations' => average(conversation_total, accounts.size),
        'Messages' => average_messages
      },
      chartData: multi_dataset_chart(
        [
          { label: 'Conversations', data: conversation_daily_count_by_date, background_color: 'rgb(31, 147, 255)' },
          { label: 'Messages', data: conversation_daily_messages_by_date, background_color: 'rgb(20, 184, 166)' }
        ]
      ),
      dealershipRows: accounts.map do |account|
        conversation_count = conversations_count_by_account[account.id].to_i
        total_account_messages = messages_count_by_account[account.id].to_i

        {
          dealershipId: account.dealership_id,
          dealershipName: account.name,
          newConversations: conversation_count,
          totalMessages: total_account_messages,
          avgMessagesPerConversation: average(total_account_messages, conversation_count)
        }
      end
    }
  end

  def spam_section_payload
    spam_total = total_spam_conversations
    conversation_total = total_conversations

    {
      key: 'spam',
      title: 'Spam',
      cards: [
        metric_card('Spam rate', percentage(spam_total, conversation_total), percentage: true),
      ],
      chartSummaryValue: spam_total,
      chartData: multi_dataset_chart(
        [
          { label: 'Spam conversations', data: spam_daily_count_by_date, background_color: 'rgb(239, 68, 68)' }
        ]
      ),
      dealershipRows: accounts.map do |account|
        conversation_count = conversations_count_by_account[account.id].to_i
        spam_count = spam_count_by_account[account.id].to_i

        {
          dealershipId: account.dealership_id,
          dealershipName: account.name,
          spamConversations: spam_count,
          spamRate: percentage(spam_count, conversation_count)
        }
      end
    }
  end

  def bookings_section_payload
    booking_count_total = booking_counts_by_account.values.sum
    conversation_total = total_conversations
    selected_dealership = dealership_id.present?

    {
      key: 'bookings',
      title: 'Bookings',
      cards: selected_dealership ? bookings_single_dealership_cards(booking_count_total, conversation_total) : bookings_all_dealership_cards(booking_count_total),
      chartData: selected_dealership ? bookings_daily_chart_data : bookings_chart_data,
      chartSummaryValue: booking_count_total,
      dealershipRows: bookings_by_dealership_rows
    }
  end

  def escalations_section_payload
    selected_dealership = dealership_id.present?

    {
      key: 'escalations',
      title: 'Escalations',
      cards: selected_dealership ? [
        metric_card('Escalation rate', percentage(total_escalations, total_conversations), percentage: true)
      ] : [
        metric_card('Avg escalations per dealer', average(total_escalations, accounts.size)),
        metric_card('Escalation rate', percentage(total_escalations, total_conversations), percentage: true)
      ],
      chartSummaryValue: total_escalations,
      chartData: multi_dataset_chart(
        [
          { label: 'Escalations', data: escalation_daily_count_by_date, background_color: 'rgb(249, 115, 22)' }
        ]
      ),
      dealershipRows: accounts.map do |account|
        escalation_count = escalation_count_by_account[account.id].to_i
        conversation_count = conversations_count_by_account[account.id].to_i

        {
          dealershipId: account.dealership_id,
          dealershipName: account.name,
          escalations: escalation_count,
          escalationRate: percentage(escalation_count, conversation_count)
        }
      end
    }
  end

  def handoffs_section_payload
    {
      key: 'handoffs',
      title: 'Handoffs',
      cards: [
        metric_card('Unresolved handoffs', total_unresolved_handoffs),
      ],
      chartSummaryValue: total_handoffs,
      chartData: multi_dataset_chart(
        [
          { label: 'Handoffs', data: handoff_daily_count_by_date, background_color: 'rgb(139, 92, 246)' }
        ]
      ),
      dealershipRows: accounts.map do |account|
        handoff_count = handoff_count_by_account[account.id].to_i
        unresolved_count = unresolved_handoff_count_by_account[account.id].to_i

        {
          dealershipId: account.dealership_id,
          dealershipName: account.name,
          handoffs: handoff_count,
          unresolvedHandoffs: unresolved_count,
          unresolvedRate: percentage(unresolved_count, handoff_count)
        }
      end
    }
  end

  def agent_sessions_section_payload
    {
      key: 'agent_sessions',
      title: 'Agent Sessions',
      cards: [
        metric_card('Tracked users', user_session_data[:total_users]),
        metric_card('Active sessions', user_session_data[:total_active_user_sessions]),
        metric_card('Expired sessions', user_session_data[:total_inactive_user_sessions]),
      ],
      chartData: dealership_session_chart_data,
      dealershipRows: accounts.map do |account|
        {
          dealershipId: account.dealership_id,
          dealershipName: account.name,
          trackedUsers: user_session_data[:total_users_by_account][account.id].to_i,
          activeSessions: user_session_data[:active_user_sessions_by_account][account.id].to_i,
          expiredSessions: user_session_data[:inactive_user_sessions_by_account][account.id].to_i
        }
      end,
      users: all_user_sessions_payload,
      selectedUserSession: selected_user_session_payload
    }
  end

  def all_user_sessions_payload
    user_session_data[:all_users].map do |user|
      {
        accountId: user[:account_id],
        dealershipId: user[:dealership_id],
        dealershipName: user[:dealership_name],
        userId: user[:user_id],
        userName: user[:user_name],
        userEmail: user[:user_email],
        sessionState: user[:session_state],
        sessionStartedAt: user[:session_started_at],
        sessionDurationSeconds: user[:session_duration_seconds]
      }
    end
  end

  def selected_user_session_payload
    return nil if account_id.blank? || user_id.blank?

    account_user = account_user_for_selected_session
    return nil unless account_user

    account = account_user.account

    sessions = UserSession.where(account_id: account.id, user_id: account_user.user_id).order(session_date: :asc)
    latest_session = sessions.order(session_date: :desc, created_at: :desc).first
    active_session = live_session?(account_user, latest_session)

    {
      accountId: account.dealership_id,
      dealershipId: account.dealership_id,
      dealershipName: account.name,
      userId: account_user.user_id,
      userName: account_user.user.name,
      userEmail: account_user.user.email,
      sessionState: active_session ? 'active' : (sessions.exists? ? 'expired' : 'no_activity'),
      sessionStartedAt: timestamp_to_iso8601(session_started_at_for(latest_session, active_session)),
      storedDurationSeconds: sessions.sum(:duration_seconds),
      cards: [
        metric_card('Total duration', format_duration(user_total_duration_seconds(account_user)))
      ],
      chartData: {
        labels: timeline_dates.map(&:iso8601),
        datasets: [
          {
            type: 'line',
            yAxisID: 'y',
            label: 'Session minutes',
            backgroundColor: '#1f3c4a',
            borderColor: '#1f3c4a',
            pointBackgroundColor: '#1f3c4a',
            pointBorderColor: '#1f3c4a',
            data: timeline_dates.map { |date| duration_minutes_for_date(account_user, date) }
          }
        ]
      }
    }
  end

  def account_user_for_selected_session
    account = accounts.find do |item|
      item.dealership_id.to_s == account_id.to_s || item.id.to_s == account_id.to_s
    end

    return account.account_users.includes(:user).find_by(user_id: user_id) if account.present?

    AccountUser.includes(:account, :user).find_by(user_id: user_id)
  end

  def user_session_data
    @user_session_data ||= SuperAdmin::DealerAgentPresenceService.new(accounts: accounts).perform
  end

  def dealership_session_chart_data
    labels = accounts.map(&:name)

    {
      labels: labels,
      datasets: [
        {
          type: 'bar',
          yAxisID: 'y',
          label: 'Active sessions',
          backgroundColor: 'rgb(31, 147, 255)',
          data: accounts.map { |account| user_session_data[:active_user_sessions_by_account][account.id].to_i }
        },
        {
          type: 'bar',
          yAxisID: 'y',
          label: 'Expired sessions',
          backgroundColor: 'rgb(148, 163, 184)',
          data: accounts.map { |account| user_session_data[:inactive_user_sessions_by_account][account.id].to_i }
        }
      ]
    }
  end

  def user_total_duration_seconds(account_user)
    sessions = UserSession.where(account_id: account_user.account_id, user_id: account_user.user_id)
    sessions.sum(:duration_seconds) + live_duration_seconds(account_user)
  end

  def live_duration_seconds(account_user)
    latest_session = UserSession.where(account_id: account_user.account_id, user_id: account_user.user_id).order(session_date: :desc, created_at: :desc).first
    return 0 unless live_session?(account_user, latest_session)
    return 0 unless latest_session&.session_started_at.present?

    [Time.current.to_i - latest_session.session_started_at.to_i, 0].max
  end

  def duration_minutes_for_date(account_user, date)
    session = UserSession.find_by(account_id: account_user.account_id, user_id: account_user.user_id, session_date: date)
    return 0 unless session

    total_seconds = session.duration_seconds
    total_seconds += [Time.current.to_i - session.session_started_at.to_i, 0].max if live_session?(account_user, session) && session.session_started_at.present?

    (total_seconds / 60.0).round(2)
  end

  def session_started_at_for(session, active_session)
    return session&.session_started_at if active_session

    nil
  end

  def live_session?(account_user, session)
    return false unless session&.session_started_at.present?

    now = Time.current
    timeout_cutoff = now - AccountUser::SESSION_ACTIVE_TIMEOUT

    return true if account_user.active_at.present? && account_user.active_at >= timeout_cutoff
    return true if redis_user_present?(account_user)
    return true if session.session_started_at >= timeout_cutoff

    false
  end

  def redis_user_present?(account_user)
    ::OnlineStatusTracker.get_presence(account_user.account_id, 'User', account_user.user_id)
  end

  def booking_counts_by_account
    @booking_counts_by_account ||= accounts.each_with_object({}) do |account, result|
      result[account.id] = fetch_booking_count(account)
    end
  end

  def bookings_all_dealership_cards(booking_count_total)
    [
      metric_card('Avg bookings per dealer', average(booking_count_total, accounts.size)),
      metric_card('Avg bookings per day', average(booking_count_total, timeline_dates.size)),
      metric_card('Booking rate', percentage(booking_count_total, total_conversations), percentage: true)
    ]
  end

  def bookings_single_dealership_cards(booking_count_total, conversation_total)
    [
      metric_card('Avg bookings per day', average(booking_count_total, timeline_dates.size)),
      metric_card('Booking rate', percentage(booking_count_total, conversation_total), percentage: true)
    ]
  end

  def fetch_booking_count(account)
    return 0 if account.dealership_id.blank?

    Bookings::BookingService.new(account.dealership_id).fetch_bookings(
      page: 1,
      page_size: 1,
      created_at_after: since.to_date.iso8601,
      created_at_before: until_time.to_date.iso8601
    )[:count].to_i
  rescue StandardError
    0
  end

  def bookings_chart_data
    category_chart(
      [
        { label: 'Bookings', data: booking_counts_by_account, background_color: 'rgb(34, 197, 94)' }
      ]
    )
  end

  def bookings_daily_chart_data
    timeline_chart(
      bookings_daily_counts_by_date,
      'Bookings',
      'rgb(34, 197, 94)'
    )
  end

  def bookings_by_dealership_rows
    accounts.map do |account|
      booking_count = booking_counts_by_account[account.id].to_i
      conversation_count = conversations_count_by_account[account.id].to_i

      {
        dealershipId: account.dealership_id,
        dealershipName: account.name,
        bookings: booking_count,
        bookingRate: percentage(booking_count, conversation_count)
      }
    end
  end

  def bookings_daily_counts_by_date
    @bookings_daily_counts_by_date ||= selected_dealership_booking_results.each_with_object(Hash.new(0)) do |booking, result|
      booking_date = timestamp_to_date(booking['created_at'] || booking[:created_at])
      result[booking_date] += 1 if booking_date.present?
    end
  end

  def selected_dealership_booking_results
    @selected_dealership_booking_results ||= begin
      account = accounts.first
      return [] unless account

      booking_service = Bookings::BookingService.new(account.dealership_id)
      page = 1
      page_size = 100
      results = []

      loop do
        response = booking_service.fetch_bookings(
          page: page,
          page_size: page_size,
          created_at_after: since.to_date.iso8601,
          created_at_before: until_time.to_date.iso8601
        )

        results.concat(Array(response[:results]))

        break if response[:next].blank?

        page = next_page_number(response[:next], page)
        break if page.nil? || page > 100
      end

      results
    rescue StandardError
      []
    end
  end

  def next_page_number(next_value, current_page)
    return next_value.to_i if next_value.respond_to?(:to_i) && next_value.to_i.positive?

    parsed_page = next_value.to_s[/[?&]page=(\d+)/, 1]
    return parsed_page.to_i if parsed_page.present?

    current_page + 1
  end

  def accounts
    @accounts ||= filtered_accounts.to_a
  end

  def all_accounts
    @all_accounts ||= Account.active
                             .where.not(dealership_id: [nil, '', CRUISE_DEMO_DEALERSHIP_ID])
                             .select(:id, :name, :dealership_id)
                             .order(:name)
                             .to_a
  end

  def filtered_accounts
    scope = all_accounts
    dealership_id.present? ? scope.select { |account| account.dealership_id == dealership_id } : scope
  end

  def account_ids
    @account_ids ||= accounts.map(&:id)
  end

  def filtered_conversations
    @filtered_conversations ||= Conversation.unscoped.where(
      account_id: account_ids,
      created_at: since..until_time
    )
  end

  def tagged_conversations(label_name)
    filtered_conversations
      .joins("INNER JOIN taggings ON taggings.taggable_id = conversations.id AND taggings.taggable_type = 'Conversation' AND taggings.context = 'labels'")
      .joins('INNER JOIN tags ON tags.id = taggings.tag_id')
      .where(tags: { name: label_name })
      .distinct
  end

  def unresolved_handoff_conversations
    @unresolved_handoff_conversations ||= tagged_conversations(HANDOFF_LABEL)
                                          .where(handoff_attended_at: nil)
  end

  def conversations_count_by_account
    @conversations_count_by_account ||= filtered_conversations.group(:account_id).count
  end

  def messages_count_by_account
    @messages_count_by_account ||= Message.unscoped.where(
      account_id: account_ids,
      conversation_id: filtered_conversations.select(:id),
      created_at: since..until_time,
      private: false
    ).where.not(message_type: Message.message_types[:activity]).group(:account_id).count
  end

  def spam_count_by_account
    @spam_count_by_account ||= filtered_conversations.where(is_spam: true).group(:account_id).count
  end

  def escalation_count_by_account
    @escalation_count_by_account ||= tagged_conversations(ESCALATION_LABEL).group(:account_id).count('conversations.id')
  end

  def handoff_count_by_account
    @handoff_count_by_account ||= tagged_conversations(HANDOFF_LABEL).group(:account_id).count('conversations.id')
  end

  def unresolved_handoff_count_by_account
    @unresolved_handoff_count_by_account ||= unresolved_handoff_conversations.group(:account_id).count('conversations.id')
  end

  def conversation_daily_count_by_date
    @conversation_daily_count_by_date ||= count_relation_by_date(
      filtered_conversations,
      column_sql: 'conversations.created_at'
    )
  end

  def conversation_daily_messages_by_date
    @conversation_daily_messages_by_date ||= count_relation_by_date(
      filtered_messages,
      column_sql: 'messages.created_at'
    )
  end

  def spam_daily_count_by_date
    @spam_daily_count_by_date ||= count_relation_by_date(
      filtered_conversations.where(is_spam: true),
      column_sql: 'conversations.created_at'
    )
  end

  def escalation_daily_count_by_date
    @escalation_daily_count_by_date ||= count_relation_by_date(
      tagged_conversations(ESCALATION_LABEL),
      column_sql: 'conversations.created_at'
    )
  end

  def handoff_daily_count_by_date
    @handoff_daily_count_by_date ||= count_relation_by_date(
      tagged_conversations(HANDOFF_LABEL),
      column_sql: 'conversations.created_at'
    )
  end

  def filtered_messages
    @filtered_messages ||= Message.unscoped.where(
      account_id: account_ids,
      conversation_id: filtered_conversations.select(:id),
      created_at: since..until_time,
      private: false
    ).where.not(message_type: Message.message_types[:activity])
  end

  def count_relation_by_date(relation, column_sql:)
    grouped_counts = relation.group(Arel.sql("DATE(#{column_sql})")).count.transform_keys do |date|
      date.respond_to?(:to_date) ? date.to_date : Date.parse(date.to_s)
    end

    timeline_hash { |date| grouped_counts[date].to_i }
  end

  def timeline_dates
    @timeline_dates ||= (since.to_date..until_time.to_date).to_a
  end

  def timeline_labels
    @timeline_labels ||= timeline_dates.map { |date| date.strftime('%d %b') }
  end

  def timeline_hash
    timeline_dates.each_with_object({}) do |date, result|
      result[date] = yield(date)
    end
  end

  def multi_dataset_chart(datasets)
    {
      labels: timeline_labels,
      datasets: datasets.map do |dataset|
        {
          type: 'bar',
          yAxisID: 'y',
          label: dataset[:label],
          backgroundColor: dataset[:background_color],
          data: timeline_dates.map { |date| dataset[:data][date].to_i }
        }
      end
    }
  end

  def timeline_chart(data_by_date, label, background_color)
    {
      labels: timeline_labels,
      datasets: [
        {
          type: 'bar',
          yAxisID: 'y',
          label: label,
          backgroundColor: background_color,
          data: timeline_dates.map { |date| data_by_date[date].to_i }
        }
      ]
    }
  end

  def timestamp_to_date(timestamp)
    return if timestamp.blank?

    return timestamp.to_date if timestamp.respond_to?(:to_date)

    timestamp_value = timestamp.to_s
    if timestamp_value.match?(/\A\d{4}-\d{2}-\d{2}/)
      parsed_timestamp = Time.zone.parse(timestamp_value)
      return parsed_timestamp.to_date if parsed_timestamp.present?
    end

    Time.zone.at(timestamp_value.to_i).to_date
  rescue StandardError
    nil
  end

  def category_chart(datasets)
    {
      labels: accounts.map(&:name),
      datasets: datasets.map do |dataset|
        {
          type: 'bar',
          yAxisID: 'y',
          label: dataset[:label],
          backgroundColor: dataset[:background_color],
          data: accounts.map { |account| dataset[:data][account.id].to_i }
        }
      end
    }
  end

  def total_conversations
    conversations_count_by_account.values.sum
  end

  def total_messages
    messages_count_by_account.values.sum
  end

  def total_spam_conversations
    spam_count_by_account.values.sum
  end

  def total_escalations
    escalation_count_by_account.values.sum
  end

  def total_handoffs
    handoff_count_by_account.values.sum
  end

  def total_unresolved_handoffs
    unresolved_handoff_count_by_account.values.sum
  end

  def non_zero_count(count_hash)
    count_hash.values.count { |count| count.to_i.positive? }
  end

  def metric_card(label, value, percentage: false)
    {
      label: label,
      value: value,
      percentage: percentage
    }
  end

  def format_duration(total_seconds)
    seconds = total_seconds.to_i
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    remaining_seconds = seconds % 60

    [hours, minutes, remaining_seconds].map { |segment| format('%02d', segment) }.join(':')
  end

  def average(total, count)
    return 0.0 if count.to_i.zero?

    (total.to_f / count).round(2)
  end

  def percentage(numerator, denominator)
    return 0.0 if denominator.to_i.zero?

    ((numerator.to_f / denominator) * 100).round(2)
  end

  def timestamp_to_iso8601(timestamp)
    return if timestamp.blank?

    Time.zone.at(timestamp).iso8601
  end
end
