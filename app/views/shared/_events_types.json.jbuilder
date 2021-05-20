types_event_count = get_type_event_count(events) unless params[:query]
json.types do
  json.phone_interview do
    json.label 'Phone Interview'
    if params[:query]
      json.event_count get_search_events_count(
        @search_params,
        { types: ['Phone Interview'], only_count: true }
      )
    else
      json.event_count types_event_count['Phone Interview']
    end
  end

  json.onsite_interview do
    json.label 'On-site Interview'
    if params[:query]
      json.event_count get_search_events_count(
        @search_params,
        { types: ['Onsite Interview'], only_count: true }
      )
    else
      json.event_count types_event_count['Onsite Interview']
    end
  end

  json.video_interview do
    json.label 'Video Interview'
    if params[:query]
      json.event_count get_search_events_count(
        @search_params,
        { types: ['Video Interview'], only_count: true }
      )
    else
      json.event_count types_event_count['Video Interview']
    end
  end
end
