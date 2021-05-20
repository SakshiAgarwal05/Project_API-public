class MatchingJobTitle < ApplicationRecord
  # field :name, type: String
  # field :abbr, type: String

  validates :name, :abbr, presence: true
  validates :name, uniqueness: true
end
