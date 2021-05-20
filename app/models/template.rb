# Template
class Template < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include ES::ESTemplate

  validates :name, presence: true
  validates :name,
            uniqueness: {
              message: "A Template with the name %{value} already exists, please choose a different name.",
            },
            allow_blank: true

  belongs_to :user, validate: false

  has_many :questions_templates, dependent: :delete_all
  has_many :questions, through: :questions_templates, dependent: :delete_all

  has_many :taggings, as: :taggable, dependent: :delete_all
  has_many :tags, through: :taggings

  accepts_nested_attributes_for :questions
  alias_for_nested_attributes :questions=, :questions_attributes=

  validate :presence_of_questions

  private

  def presence_of_questions
    return true if questions.size > 0

    errors.add(:base, 'You must select at least 1 question')
  end
end
