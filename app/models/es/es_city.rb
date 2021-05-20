module ES
  module ESCity
    def self.included(receiver)
      receiver.class_eval do
        index_name ES::ESCommon.indexify('cities')
        settings(
          index: ES::ESCommon.index_settings,
          analysis: ES::ESCommon.analysis
        ) do
          mapping do
            indexes :id, type: 'keyword'
            indexes :name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :downcase_folding
            end
            indexes :abbr, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :downcase_folding
            end
            indexes :country_id, type: 'keyword'
            indexes :state_id, type: 'keyword'
          end
        end
      end
    end

    def as_indexed_json(options = {})
      {
        id: id,
        name: name,
        abbr: abbr,
        country_id: state.try(:country_id),
        state_id: state_id
      }
    end
  end
end