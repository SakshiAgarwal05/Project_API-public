module ES
  module ESCommon
    FILTERS = {
      autocomplete: {
        type: 'edge_ngram',
        min_gram: 1,
        max_gram: 20
      },
      postal_code_edge_ngram: {
        type: 'edge_ngram',
        min_gram: 3,
        max_gram: 10
      },
      ten_digits_min: {
        type: "length",
        min: 10
      },
      not_empty: {
        type: "length",
        min: 1
      },
      letters_and_digits_only: {
        # tokenizer: 'standard',
        pattern: '[^a-zA-Z0-9]',
        type: 'pattern_replace',
        replacement: ''
      }
    }.freeze

    CHAR_FILTERS = {
      html_strip: {
        type: 'html_strip'
      },
      postal_code_ca: {
        type: 'pattern_replace',
        pattern: '([ABCEGHJKLMNPRSTVXYabceghjklmnprstvxy][0-9]\\w)\\s*(\\d\\w\\d)?',
        replacement: '$1 $2'
      },
      postal_code_us: {
        type: 'pattern_replace',
        pattern: '([0-9]{5})\\s*-?\\s*([0-9]{4})?',
        replacement: '$1 $2'
      },
      digits_only: {
        type: 'pattern_replace',
        pattern: "[^\\d]"
      },
      letters_and_digits_only: {
        type: 'pattern_replace',
        pattern: '[^a-zA-Z0-9]',
        replacement: ""
      }
    }.freeze


    ANALYZERS = {
      downcase_folding: {
        tokenizer: 'standard',
        filter: %w[asciifolding lowercase]
      },
      autocomplete: {
        tokenizer: 'standard',
        filter: %w[asciifolding lowercase autocomplete]
      },
      html_strip_folding: {
        tokenizer: 'standard',
        char_filter: %w[html_strip],
        filter: %w[asciifolding lowercase]
      },
      postal_code_index: {
        tokenizer: 'keyword',
        filter: %w[lowercase trim],
        char_filter: %w[postal_code_ca postal_code_us]
      },
      postal_code_search: {
        tokenizer: 'keyword',
        filter: %w[lowercase trim postal_code_edge_ngram],
        char_filter: %w[postal_code_ca postal_code_us]
      },
      url: {
        tokenizer: 'uax_url_email'
      },
      phone_number: {
        char_filter: 'digits_only',
        tokenizer: 'keyword',
        filter: %w[ten_digits_min]
      },
      phone_number_search: {
        char_filter: 'digits_only',
        tokenizer: 'keyword',
        filter: %w[not_empty]
      },
      lower_letters_and_digits_search: {
        tokenizer: 'standard',
        char_filter: ['letters_and_digits_only'],
        filter: "lowercase"
      },
      autocomplete_ngram: {
        tokenizer: 'standard',
        char_filter: [],
        filter: ['asciifolding', 'lowercase', 'letters_and_digits_only']
      },
      fulltext: {
        type: "custom",
        tokenizer: "whitespace",
        filter: ["lowercase", "type_as_payload"]
      }
    }.freeze

    NORMALIZERS = {
      lowercase: {
        type: 'custom',
        char_filter: %w[],
        filter: %w[lowercase],
      },
      lower_letters_and_digits_only: {
        type: 'custom',
        char_filter: ['letters_and_digits_only'],
        filter: "lowercase"
      }
    }.freeze

    def self.analysis
      {
        filter: FILTERS,
        char_filter: CHAR_FILTERS,
        analyzer: ANALYZERS,
        normalizer: NORMALIZERS
      }
    end

    def self.index_settings(
      number_of_shards: Rails.configuration.elasticsearch[:number_of_shards],
      number_of_replicas: Rails.configuration.elasticsearch[:number_of_replicas]
    )
      {
        number_of_shards: number_of_shards,
        number_of_replicas: number_of_replicas,
      }
    end

    def self.indexify(name)
      if Rails.configuration.elasticsearch[:index_suffix]
        "#{name}-#{Rails.env}-#{Rails.configuration.elasticsearch[:index_suffix]}"
      else
        "#{name}-#{Rails.env}"
      end
    end
  end
end
