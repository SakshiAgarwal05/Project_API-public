class Degree < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESDegree

  validates :name, presence: true
  validates_uniqueness_of :name, :case_sensitive => false

  class << self
    def search_degree(params)
      search = ES::SearchDegree.new(params)
      search.search_degree
    end
  end
end
