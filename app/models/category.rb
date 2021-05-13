class Category < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESCategory

  has_many :jobs
  # field :name, type: String
  validates :name, presence: true, uniqueness: true

  scope :sortit, ->(order_field, order) {
    default_order = order.presence || 'asc'
    order_field = order_field.presence || 'name'
    case order_field
    when 'cs_active_jobs_count'
      joins('left join jobs on jobs.category_id = categories.id').
        where({
          jobs: {
            stage: Job::STAGES_FOR_APPLICATION,
            locked_at: nil,
            publish_to_cs: true,
          },
        }).
        select('categories.*, count(jobs.id) as jobs_count').group('categories.id').
        order(jobs_count: default_order)
    else
      order(order_field => default_order)
    end
  }

  class << self
    def search_category(params)
      search = ES::SearchCategory.new(params)
      search.search_category
    end
  end
end
