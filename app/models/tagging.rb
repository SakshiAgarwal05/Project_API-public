class Tagging < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include ES::ESTagging

  belongs_to :tag
  belongs_to :taggable, polymorphic: true
end
