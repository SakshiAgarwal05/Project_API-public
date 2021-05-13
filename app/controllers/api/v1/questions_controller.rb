# View default questions[Question.html]
class QuestionsController < ApplicationController
  respond_to :json

  # list all questions
  # ====URL
  #   /questipns [GET]
  def index
    @questions = TemplateService.load_default_questions
  end
end
