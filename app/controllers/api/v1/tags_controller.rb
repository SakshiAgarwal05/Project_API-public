# View all tags
class Api::V1:: TagsController < ApplicationController
  # list all tags
  # ====URL
  #   /tags [GET]
  # ====PARAMETERS
  # ====Parameters
  # query
  # order_field (sort by fields name)
  # order (sort order asc/desc)
  # page (page number)
  # per_page (records per page)
  # taggable_type
  def index
    if params[:query].present? && params[:taggable_type].present?
      search = ES::SearchTagging.new(
        params.permit(:query, :per_page, :page, :taggable_type), current_user
      )
      taggings, @total_count = search.search_taggings
      @tags = Tag.where(id: taggings.map(&:tag_id))
    else
      @tags = Tag.
        where(id: Tagging.where(taggable_type: params[:taggable_type]&.humanize).select(:tag_id)).
        order(name: :asc).
        limit(10)
    end

    render 'shared/tags', status: :ok
  end
end
