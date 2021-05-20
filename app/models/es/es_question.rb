module ES
  module ESQuestion
    def self.included(receiver)
      receiver.class_eval do
        index_name ES::ESCommon.indexify('questions')
        settings(
          index: ES::ESCommon.index_settings,
          analysis: ES::ESCommon.analysis
        ) do
          mapping do
            indexes :id, type: 'keyword'
            indexes :questionnaire_id, type: 'keyword'
            indexes :is_shared, type: 'boolean'

            indexes :question, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :downcase_folding
            end

            indexes :tags, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
          end
        end
      end
    end

    def as_indexed_json(options = {})
      {
        id: id,
        question: question,
        questionnaire_id: questionnaire_id,
        is_shared: is_shared,
        tags: tags.pluck(:name),
      }
    end
  end
end
