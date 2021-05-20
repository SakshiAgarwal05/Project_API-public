module ES
  module ESShareLink
    def self.included(receiver)
      receiver.class_eval do
        index_name ES::ESCommon.indexify('share_links')
        settings(
          index: ES::ESCommon.index_settings,
          analysis: ES::ESCommon.analysis
        ) do
          mapping do
            indexes :id, type: 'keyword'
            indexes :user_id, type: 'keyword'
            indexes :agency_id, type: 'keyword'
            indexes :user_hiring_organization_id, type: 'keyword'
            indexes :hiring_organization_id, type: 'keyword'
            indexes :client_id, type: 'keyword'
            indexes :industry_id, type: 'keyword'
            indexes :category_id, type: 'keyword'
            indexes :shared_id, type: 'keyword'
            indexes :shared_type, type: 'keyword'
            indexes :created_at, type: 'date'
          end
        end
      end
    end

    def as_indexed_json(options = {})
      return {} unless created_by
      json = {
        id: id,
        user_id: created_by_id,
        shared_type: shared_type,
        shared_id: shared_id,
        agency_id: created_by.agency_id,
        user_hiring_organization_id: created_by.hiring_organization_id,
        created_at: created_at,
      }

      case shared_type
      when "Job"
        json.merge!(
          hiring_organization_id: shared.hiring_organization_id,
          client_id: shared.client_id,
          industry_id: shared.industry_id,
          category_id: shared.category_id
        ) if shared
      end

      json
    end
  end
end
