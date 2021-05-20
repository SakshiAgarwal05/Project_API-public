class Certificate < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESCertificate
  extend ES::SearchCertificate

  belongs_to :vendor
  has_many :certifications

  validates :name, presence: true, uniqueness: {scope: :vendor}
end
