class ES::SearchEvent
  include ES::Search

  def terms_fields
    [
      :client_id,
      :industry_id,
      :category_id,
    ]
  end

  def term_fields
    [:hiring_organization_id]
  end

  def terms_keywords_fields
    []
  end

  def cross_fields
    [
      "title^30",
      "job_title^30",
      "display_job_id^30",
      "cs_job_id^30",
      "job_id^30",
      "job_job_id.autocomplete^15",
      "display_job_id.autocomplete^15",
      "cs_job_id.autocomplete^15",
      "title.autocomplete^15",
      "job_job_id.autocomplete_ngram^10",
      "display_job_id.autocomplete_ngram^10",
      "cs_job_id.autocomplete_ngram",
      "client_name^5",
    ]
  end

  def search_events
    add_filters
    add_should
    if params[:query].present?
      UserSearch.find_or_create_by(
        user: user,
        search_tag: params[:query],
        related_to: 'Event'
      )
    end
    return_paginated_response(Event)
  end

  def aggs_search_events(aggs, add_filter)
    params[:skip_ho_filter] = true if user.role_group.eql?(3)
    add_common_filters
    self.filters += add_filter
    return_aggs_response(Event, aggs)
  end

  def add_should
    return unless params[:query]
    add_common_should
  end

  def add_filters
    my_job_filters
    @filters += [{ term: { active: true } }] unless params[:closed_jobs]
    @filters += [{ terms: { client_id: params[:client_ids] } }] if params[:client_ids]
    @filters += [{ terms: { job_id: params[:job_ids] } }] if params[:job_ids]
    @filters += [{ terms: { attendees: params[:user_ids] } }] if params[:users_ids]
    @filters += [{ terms: { attendee_emails: params[:attendee_emails] } }] if params[:attendee_emails]
    params[:types] = Event::EVENT_TYPES unless params[:types].present?
    @filters += [{ terms: { event_type: params[:types] } }]
    status_filter unless params[:all_status].is_true?
  end

  def status_filter
    if params[:declined_events].is_true? &&
      params[:scheduled_events].is_true? &&
      params[:in_progress_events].is_true? &&
      params[:requested_events].is_true? &&
      params[:expired_events].is_true? &&
      params[:completed_events].is_true?

      return records
    end

    query = []
    query += [{ term: { declined: true } }] if params[:declined_events]

    if params[:requested_events] || params[:expired_events]
      sub_query = [{ term: { declined: false } }, { term: { confirmed: false } }]
      if params[:requested_events] && !params[:expired_events]
        sub_query += [{ bool: {
          should: [
            { range: { start_date_time: { gte: Time.now } } },
            { bool: { must: [{ term: { confirmed: false } }, { range: { expire_at: { gte: Time.now } } }] } },
          ],
          minimum_should_match: 1,
        } }]
      elsif params[:expired_events] && !params[:requested_events]
        sub_query += [{ bool: {
          should: [
            { range: { start_date_time: { lt: Time.now } } },
            { bool: { must: [{ term: { confirmed: false } }, { range: { expire_at: { lt: Time.now } } }] } }

            ],
          minimum_should_match: 1,
        }}]
      end
      query += [{ bool: { must: sub_query } }]
    end

    if params[:scheduled_events] || params[:in_progress_events] || params[:completed_events]
      sub_query1 = [{ term: { declined: false } }, { term: { confirmed: true } }]
      if params[:scheduled_events] && params[:in_progress_events] && !params[:completed_events]
        sub_query2 = sub_query1 + [{ range: { end_date_time: { gte: Time.now } } }]
      elsif !params[:scheduled_events] && params[:in_progress_events] && params[:completed_events]
        sub_query2 = sub_query1 + [{ range: { start_date_time: { lt: Time.now } } }]
      end

      unless sub_query2
        if params[:scheduled_events]
          sub_query2 = sub_query1 + [{ range: { start_date_time: { gt: Time.now } } }]
        elsif params[:in_progress_events]
          sub_query2 = sub_query1 + [{ range: { start_date_time: { lt: Time.now } } }, { range: { end_date_time: { gte: Time.now } } }]
        elsif params[:completed_events]
          sub_query2 = sub_query1 + [{ range: { end_date_time: { lt: Time.now } } }]
        end
      end
      sub_query2 = sub_query1 unless sub_query2
      query += [{ bool: { must: sub_query2 } }]
    end
    if query.any?
      @filters += [{ bool: { should: query, minimum_should_match: 1 } }]
    end
  end
end
