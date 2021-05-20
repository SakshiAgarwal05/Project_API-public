class State < ApplicationRecord
  # TODO: Temp commented to avoid HTTParty & mongoid
  # indexes issue.
  include Concerns::Timezonable
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESState
  extend ES::SearchState

  validates :name, presence: true
  has_many :cities
  belongs_to :country
  accepts_nested_attributes_for :cities
  alias_for_nested_attributes :cities=, :cities_attributes=

  # index(name: 1)
end
