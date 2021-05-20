class Skill < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include ES::ESSkill

  has_and_belongs_to_many :agencies
  has_and_belongs_to_many :users
  has_and_belongs_to_many :talents
  has_and_belongs_to_many :jobs

  # Depricated
  alias_attribute :partners, :agencies
  alias_attribute :partner_ids, :agency_ids

  validates :name, presence: true,
    length: { minimum: 1, maximum: 80 },
    format: { without: /[\,|\t|\;|[^(\u0000-\u0080)]]/ },
    uniqueness: true #{ case_sensitive: false }

  validate :skill_name_format, on: :create

  # Delete Cache skills redis cache after update
  after_save{ Rails.cache.delete('skills')}
  after_destroy{ Rails.cache.delete('skills')}


  def skill_name_format
    errors.add(:base, "This doesn't seems like a skill") if Skill.check_if_invalid_name(name).is_true?
  end

  # please define class methods here.
  class << self
    def search_skills(params)
      search = ES::SearchSkill.new(params)
      search.search_skills
    end
    # Low Level caching added for skills
    def cached_skills
      Rails.cache.fetch('skills', expires_in: 1.month) do
        Skill.order
      end
    end

    # Persists newly received skills and assigns source = 'beeline'
    # @return Array of skill_ids to be assigned to a job
    def merge_skills(skills, source = nil)
      return unless skills
      skills = skills.collect{|skill| skill.strip}
      existing_skills = where("lower(name) in (?)", skills.collect{|skill| skill.downcase})
      to_create_skills = (skills - existing_skills.map(&:name)).collect{
          |skill| skill if check_if_invalid_name(skill).is_false?
        }.flatten.compact.uniq
      skill_names = to_create_skills.
        map(&:sanitize_skills).
        reject(&:blank?).
        collect{ |skill| { name: skill, source: source } }.
        uniq
      new_skills =  Skill.bulk_import(skill_names, validate: false)
      existing_skills.map(&:id) + new_skills.ids
    end

    def check_if_invalid_name(skill_name)
      skill_name = skill_name.downcase
      array_of_values = ['degree', 'bachelor', 'master of', 'masters of', 'certificate']
      array_of_values.any?{ |x| skill_name.downcase.match(x) }
    end
  end
end
