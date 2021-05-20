# ResumeTemplate
class ResumeTemplate < ApplicationRecord
  validates :name, :content, presence: true
  validates_uniqueness_of :name

  has_many :clients
end
