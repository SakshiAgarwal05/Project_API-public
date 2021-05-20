class Tag < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include ES::ESTag
  extend ES::SearchTag

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :profiles, through: :taggings, source: :taggable, source_type: 'Profile'
  has_many :questions, through: :taggings, source: :taggable, source_type: 'Question'
  has_many :templates, through: :taggings, source: :taggable, source_type: 'Template'
end
