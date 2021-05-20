class Vendor < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESVendor
  extend ES::SearchVendor

  # field :name, type: String
  has_many :certificates

  validates :name, presence: true, uniqueness: true
  after_save{ Rails.cache.delete("vendors") }

  # Low Level caching added for Vendors
  class << self # please define class methods here.
    def cached_vendors
      Rails.cache.fetch("vendors", expires_in: 1.month) do
        Vendor.order(:name)
      end
    end
  end # END of Class methods.

  private
end
