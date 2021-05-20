module ES
  module ESClient
    def self.included(receiver)
      receiver.class_eval do
        index_name ES::ESCommon.indexify('clients')
        settings(
          index: ES::ESCommon.index_settings,
          analysis: ES::ESCommon.analysis
        ) do
          mapping do
            indexes :id, type: 'keyword'

            indexes :company_name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
              indexes :autocomplete,
                      type: 'text',
                      analyzer: :autocomplete,
                      search_analyzer: :downcase_folding
            end
            indexes :city, type: 'text', analyzer: :downcase_folding, term_vector: 'yes' do
              indexes :keyword, type: 'keyword'
              indexes :vector,
                      type: 'text',
                      analyzer: :downcase_folding,
                      term_vector: :with_positions_offsets_payloads
            end

            indexes :country_obj_name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :country_obj_abbr, type: 'keyword', normalizer: :lowercase

            indexes :state_obj, type: 'text', analyzer: :downcase_folding, term_vector: 'yes' do
              indexes :keyword, type: 'keyword'
              indexes :vector,
                      type: 'text',
                      analyzer: :downcase_folding,
                      term_vector: :with_positions_offsets_payloads
            end
            indexes :state_obj_abbr, type: 'keyword', normalizer: :lowercase
            indexes :postal_code, type: 'keyword', normalizer: :lower_letters_and_digits_only

            indexes :website, type: 'text', analyzer: :url
            indexes :about, type: 'text', analyzer: :english
            indexes :active, type: 'boolean'
            indexes :status, type: 'keyword', normalizer: :lowercase
            indexes :industry_name, type: 'keyword', normalizer: :lowercase
            indexes :supervisor_ids, type: 'keyword'
            indexes :account_manager_ids, type: 'keyword'
            indexes :onboarding_agent_ids, type: 'keyword'
            indexes :saved_by_ids, type: 'keyword'
          end
        end
      end
    end

    def as_indexed_json(options = {})
      {
        id: id,
        company_name: company_name,
        city: city,
        postal_code: postal_code,
        country_obj_name: (country_obj ? (country_obj['name'] || '') : ''),
        country_obj_abbr: (country_obj ? (country_obj['abbr'] || '') : ''),
        state_obj_name: (state_obj ? (state_obj['name'] || '') : ''),
        state_obj_abbr: (state_obj ? (state_obj['abbr'] || '') : ''),
        website: website,
        about: ActionView::Base.full_sanitizer.sanitize(about),
        active: active,
        status: status,
        industry_name: industry_name,
        supervisor_ids: supervisors.pluck(:user_id),
        account_manager_ids: account_managers.pluck(:user_id),
        onboarding_agent_ids: onboarding_agents.pluck(:user_id),
        saved_by_ids: saved_by_ids,
      }
    end
  end
end
