# ====Fields<br>
# *_id* (BSON::ObjectId)<br>
# *deleted_at* (Time)<br>
# *name* (String)<br>
# *agency_ids* (Array)<br>
# ------
class Position < ApplicationRecord
  acts_as_paranoid
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESPosition
  extend ES::SearchPosition

  # field :name, type: String
  has_and_belongs_to_many :agencies, autosave: true


  # Delete Cache positions redis cache after update
  after_save{ Rails.cache.delete("positions")}
  after_destroy{ Rails.cache.delete("positions")}

  # Low Level caching added for positions
  class << self # please define class methods here.
    def cached_positions
      Rails.cache.fetch("positions", expires_in: 1.month) do
        Position.order
      end
    end
  end # END of Class methods.
end
