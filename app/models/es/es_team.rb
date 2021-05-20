module ES
  module ESTeam
    def self.included(receiver)
      receiver.class_eval do
        index_name ES::ESCommon.indexify('teams')
        settings(
          index: ES::ESCommon.index_settings,
          analysis: ES::ESCommon.analysis
        ) do
          mapping do
            indexes :id, type: 'keyword'
            indexes :enabled, type: 'boolean'
            indexes :name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :downcase_folding
            end
            indexes :company_name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :downcase_folding
            end
            indexes :city, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :country_obj_name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :country_obj_abbr, type: 'keyword', normalizer: :lowercase
            indexes :state_obj_name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :state_obj_abbr, type: 'keyword', normalizer: :lowercase
            indexes :postal_code, type: 'text', analyzer: :postal_code_index, search_analyzer: :postal_code_search do
              indexes :keyword, type: 'keyword'
            end
          end
        end
      end
    end

    def as_indexed_json(options = {})
      {
        id: id,
        name: name,
        company_name: company_name,
        city: city,
        enabled: enabled,
        country_obj_name: (country_obj ? (country_obj['name'] || '') : ''),
        country_obj_abbr: (country_obj ? (country_obj['abbr'] || '') : ''),
        state_obj_name: (state_obj ? (state_obj['name'] || '') : ''),
        state_obj_abbr: (state_obj ? (state_obj['abbr'] || '') : ''),
        postal_code: postal_code,
      }
    end
  end
end
