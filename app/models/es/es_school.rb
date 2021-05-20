module ES
  module ESSchool
    def self.included(receiver)
      receiver.class_eval do
        index_name ES::ESCommon.indexify('schools')
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
            indexes :popularity, type: 'integer'
          end
        end
      end
    end

    def as_indexed_json(options = {})
      {
        id: id,
        name: name,
        popularity: popularity
      }
    end
  end
end