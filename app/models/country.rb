class Country < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESCountry
  extend ES::SearchCountry

  has_many :states

  default_scope ->{order("position asc")}
  has_and_belongs_to_many :currencies, autosave: true
  validates :name, presence: true, uniqueness: true

  # Delete Cache countries redis cache after update
  after_save{ Rails.cache.delete("countries") }
  after_destroy{ Rails.cache.delete("countries")}
  scope :truncated, ->{where(truncated: true)}

  ALTERNATIVE_CODES = {
    'USA': 'US',
    'CAN': 'CA',
    'IND': 'IN',
  }.with_indifferent_access

  # Low Level caching added for Countries
  class << self # please define class methods here.
    def cached_countries
      Rails.cache.fetch("countries", expires_in: 1.month) do
        Country.truncated.order(position: "asc")
      end
    end

    def cached_all_countries
      Rails.cache.fetch("all_countries", expires_in: 1.month) do
        Country.order(name: "asc")
      end
    end

    def fetch_code(code)
      ALTERNATIVE_CODES[code]
    end
  end # END of Class methods.
end
