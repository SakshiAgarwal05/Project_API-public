json.pagination do
  json.per_page per_page
  json.page page_count
  if @total_count
    json.total_pages (@total_count.to_f / per_page.to_i).ceil
    json.total @total_count
  else
    json.total_pages @pagy&.pages || obj.total_pages
    json.total @pagy&.count || obj.total_count
  end
end
json.search_warning @warning
