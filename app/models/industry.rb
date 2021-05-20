class Industry < ApplicationRecord
  acts_as_paranoid
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESIndustry

  has_and_belongs_to_many :agencies, autosave: true
  has_many :jobs

  after_save{ Rails.cache.delete("industries") }
  after_destroy{ Rails.cache.delete("industries")}

  # Low Level caching added for industries
  class << self # please define class methods here.
    def cached_industries

      Rails.cache.fetch("industries", expires_in: 1.month) do
        Industry.order(name: :asc)
      end
    end

    def search_industry(params)
      search = ES::SearchIndustry.new(params)
      search.search_industry
    end
  end # END of Class methods.
end
