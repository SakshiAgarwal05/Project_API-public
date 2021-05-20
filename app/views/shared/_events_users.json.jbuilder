json.data users do |user|
  json.call(user, :id, :first_name, :middle_name, :last_name)
  if params[:query]
    json.event_count get_search_events_count(
      @search_params,
      { user_ids: [user.id], only_count: true }
    )
  else
    json.event_count user['events_counts']
  end
end

json.partial! 'pagination/pagination', obj: users
