# ====Fields<br>
# *_id* (BSON::ObjectId)<br>
# *name* (String)<br>
# *popularity* (Integer)<br>
# ------
class Company < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESCompany

  validates :name, presence: true
  validates_uniqueness_of :name, :case_sensitive => false

  class << self
    def search_company(params)
      search = ES::SearchCompany.new(params)
      search.search_company
    end
  end
end
