class Currency < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESCurrency

  has_and_belongs_to_many :countries, autosave: true
  validates :name, :abbr, presence: true, uniqueness: true

  class << self
    def search_currency(params)
      search = ES::SearchCurrency.new(params)
      search.search_currency
    end
  end
end
