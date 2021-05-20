# TemplatesController
class Api::V1:: TemplatesController < ApplicationController
  # List all templates names
  # ====URL
  #   /templates [GET]
  def index
    @templates = Template.order(name: :asc)
  end
end
