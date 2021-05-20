events = events.includes(:event_attendees, :user, :media, :job, :client)
related_to = TalentsJob.where(id: events.collect(&:related_to_id)).collect { |tj| { tj.id => tj } }.inject(:merge)
json.data do
  json.array! events do |event|
    json.partial! 'admin/events/list', event: event, related_to: related_to[event.related_to_id]
  end
end

json.partial! 'pagination/pagination', obj: events, total_count: total_count
