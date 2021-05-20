# ResumeTemplatesController
class Api::V1:: ResumeTemplatesController < ApplicationController
  # List Resume templates names
  # ====URL
  #   /resume_templates [GET]
  def index
    @resume_templates = ResumeTemplate.order(name: :asc)
  end
end
