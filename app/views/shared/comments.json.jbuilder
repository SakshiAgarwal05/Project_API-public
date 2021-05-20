json.data @comments.includes(:user, :mentioned, notable: [:job, :talent, :client]) do |comment|
  json.partial! partial: '/shared/comment', note: comment
end

json.partial! 'pagination/pagination', obj: @comments
