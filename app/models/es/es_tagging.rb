module ES
  module ESTagging
    def self.included(receiver)
      receiver.class_eval do
        index_name ES::ESCommon.indexify('taggings')
        settings(
          index: ES::ESCommon.index_settings,
          analysis: ES::ESCommon.analysis
        ) do
          mapping do
            indexes :id, type: 'keyword'
            indexes :tag_id, type: 'keyword'
            indexes :taggable_id, type: 'keyword'
            indexes :taggable_type, type: 'keyword', normalizer: :lowercase

            indexes :tag_name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'

              indexes :autocomplete, type: 'text',
                                     analyzer: :autocomplete,
                                     search_analyzer: :downcase_folding
            end
          end
        end
      end
    end

    def as_indexed_json(options = {})
      {
        id: id,
        tag_id: tag_id,
        taggable_id: taggable_id,
        taggable_type: taggable_type,
        tag_name: tag&.name,
      }
    end
  end
end
