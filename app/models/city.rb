class City < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESCity
  extend ES::SearchCity

  validates :name, presence: true
  belongs_to :state
end
