# ====Fields<br>
# *_id* (BSON::ObjectId)<br>
# *name* (String)<br>
# *popularity* (Integer)<br>
# ------
class School < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESSchool
  extend ES::SearchSchool

  # field :name, type: String
  # field :popularity, type: Integer, default: 0

  validates :name, presence: true
  validates_uniqueness_of :name, :case_sensitive => false

  # index(name: 1)
end
