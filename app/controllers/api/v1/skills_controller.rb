# view all skills
class SkillsController < ApplicationController

  # list skills
  # ====URL
  # /skills [GET]
  # ====PARAMETERS
  # query
  # per_page
  # page
  def index
    if params[:query].present?
      @skills, _total_count = Skill.search_skills(search_params)
      render json: @skills.to_json(only: [:name, :id]), status: :ok
    else
      render json: {error: "Query is incorrect."}, status: 422
    end
  end

  private

  def search_params
    params[:page] = page_count
    params[:per_page] = per_page
    params.permit(:query)
  end
end
