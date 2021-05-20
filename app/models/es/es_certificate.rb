module ES
  module ESCertificate
    def self.included(receiver)
      receiver.class_eval do
        index_name ES::ESCommon.indexify('certificates')
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
            indexes :vendor_id, type: 'keyword'
          end
        end
      end
    end

    def as_indexed_json(options = {})
      {
        id: id,
        name: name,
        vendor_id: vendor_id
      }
    end
  end
end