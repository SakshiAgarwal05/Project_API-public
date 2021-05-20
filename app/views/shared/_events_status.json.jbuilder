status_event_count = get_status_event_count(events) unless params[:query]

json.status do
  json.requested do
    json.label 'Pending'
    if params[:query]
      json.event_count get_search_events_count(
        @search_params,
        { requested_events: true, only_count: true }
      )
    else
      json.event_count status_event_count[:requested]
    end
  end

  json.scheduled do
    json.label 'Scheduled'
    if params[:query]
      json.event_count get_search_events_count(
        @search_params,
        { scheduled_events: true, only_count: true }
      )
    else
      json.event_count status_event_count[:scheduled]
    end
  end

  json.in_progress do
    json.label 'In-progress'
    if params[:query]
      json.event_count get_search_events_count(
        @search_params,
        { in_progress_events: true, only_count: true }
      )
    else
      json.event_count status_event_count[:in_progress]
    end
  end

  json.completed do
    json.label 'Completed'
    if params[:query]
      json.event_count get_search_events_count(
        @search_params,
        { completed_events: true, only_count: true }
      )
    else
      json.event_count status_event_count[:completed]
    end
  end

  json.declined do
    json.label 'Cancelled/Declined'
    if params[:query]
      json.event_count get_search_events_count(
        @search_params,
        { declined_events: true, only_count: true }
      )
    else
      json.event_count status_event_count[:declined]
    end
  end

  json.expired do
    json.label 'Expired'
    if params[:query]
      json.event_count get_search_events_count(
        @search_params,
        { expired_events: true, only_count: true }
      )
    else
      json.event_count status_event_count[:expired]
    end
  end

  json.maybe do
    json.label 'Tentative'
    if params[:query]
      json.event_count get_search_events_count(
        @search_params,
        { maybe_events: true, only_count: true }
      )
    else
      json.event_count status_event_count[:maybe]
    end
  end
end
