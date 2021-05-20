module ES
  module ESJob

    def self.included(receiver)
      receiver.class_eval do
        index_name ES::ESCommon.indexify('jobs')
        settings(
          index: ES::ESCommon.index_settings,
          analysis: ES::ESCommon.analysis
        ) do
          mapping do
            indexes :id, type: 'keyword'
            # a bit confused about this one, PG has agency_id but no agency_ids
            indexes :address, type: 'text', analyzer: :downcase_folding do
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
            indexes :created_at, type: 'date'
            indexes :currency, type: 'keyword', normalizer: :lowercase
            indexes :currency_obj, type: 'object' do
              indexes :id, type: 'keyword'
              indexes :abbr, type: 'keyword', normalizer: :lowercase
              indexes :name, type: 'text', analyzer: :downcase_folding
            end
            indexes :pay_period, type: 'keyword', normalizer: :lowercase
            indexes :published_at, type: 'date'
            indexes :ho_published_at, type: 'date'
            indexes :on_hold_at, type: 'date'
            indexes :closed_at, type: 'date'
            indexes :time_to_close, type: 'integer'
            indexes :stage, type: 'keyword', normalizer: :lowercase
            indexes :summary, type: 'text', analyzer: :english, term_vector: 'yes' do
              indexes :vector, type: 'text', analyzer: :english, term_vector: :with_positions_offsets_payloads
            end
            indexes :title, type: 'text', analyzer: :downcase_folding, term_vector: 'yes' do
              indexes :keyword, type: 'keyword'
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :downcase_folding
              indexes :vector, type: 'text', analyzer: :english, term_vector: :with_positions_offsets_payloads
            end
            indexes :updated_at, type: 'date'
            indexes :enable, type: 'boolean'
            indexes :available_positions, type: 'integer'
            indexes :positions, type: 'integer'
            indexes :filled_positions, type: 'integer'
            indexes :category_name, type: 'keyword', normalizer: :lowercase do
              indexes :vector,
                      type: 'text',
                      analyzer: :downcase_folding,
                      term_vector: :with_positions_offsets_payloads
            end
            indexes :client_name, type: 'text', term_vector: 'yes' do
              indexes :keyword, type: 'keyword'
              indexes :vector, type: 'text', term_vector: :with_positions_offsets_payloads
            end
            indexes :category_id, type: 'keyword'
            indexes :industry_id, type: 'keyword'
            indexes :industry_name, type: 'keyword', normalizer: :lowercase do
              indexes :vector, type: 'text', term_vector: :with_positions_offsets_payloads
            end
            indexes :duration, type: 'keyword'
            indexes :is_remote, type: 'boolean'
            indexes :location_type, type: 'keyword', normalizer: :lowercase
            indexes :skills, type: 'text', analyzer: :english, term_vector: 'yes' do
              indexes :vector, type: 'text', analyzer: :english, term_vector: :with_positions_offsets_payloads
            end
            indexes :timezone, type: 'object' do
              indexes :abbr, type: 'keyword', normalizer: :lowercase
              indexes :name, type: 'text', analyzer: :downcase_folding
            end
            indexes :stage_transitions, type: 'keyword'
            indexes :type_of_job, type: 'keyword', normalizer: :lowercase
            indexes :postal_code, type: 'keyword', normalizer: :lower_letters_and_digits_only
            indexes :cs_job_id, type: 'text' do
              indexes :keyword, type: 'keyword', normalizer: :lower_letters_and_digits_only
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :lower_letters_and_digits_search
              indexes :autocomplete_ngram, type: 'text', analyzer: :autocomplete_ngram
            end
            indexes :job_id, type: 'text' do
              indexes :keyword, type: 'keyword', normalizer: :lower_letters_and_digits_only
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :lower_letters_and_digits_search
              indexes :autocomplete_ngram, type: 'text', analyzer: :autocomplete_ngram
            end
            indexes :display_job_id, type: 'text' do
              indexes :keyword, type: 'keyword', normalizer: :lower_letters_and_digits_only
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :lower_letters_and_digits_search
              indexes :autocomplete_ngram, type: 'text', analyzer: :autocomplete_ngram
            end
            # TODO(eric@crowdstaffing.com): should this actually be called years_of_experience? this is not the same
            # years_of_experience column in the pg schema, below it's being generated by the
            # included_level_of_experiences method which transforms the object {min, max} to []
            indexes :years_of_experience, type: 'keyword'
            indexes :pay_rate_min, type: 'float'
            indexes :pay_rate_max, type: 'float'

            indexes :responsibilities, type: 'text', analyzer: :english, term_vector: 'yes' do
              indexes :vector, type: 'text', analyzer: :english, term_vector: :with_positions_offsets_payloads
            end
            indexes :preferred_qualification, type: 'text', analyzer: :english
            indexes :minimum_qualification, type: 'text', analyzer: :english
            indexes :additional_detail, type: 'text', analyzer: :english
            indexes :certifications, type: 'text' do
              indexes :keyword, type: 'keyword'
            end
            indexes :benefits, type: 'text' do
              indexes :keyword, type: 'keyword'
            end
            indexes :priority_of_status, type: 'integer'
            # TODO(eric@crowdstaffing.com): picked_by_ids does not exist as a column on the jobs table, however
            indexes :archived_by_ids, type: 'keyword'
            indexes :start_date, type: 'date'
            # TODO(eric@crowdstaffing.com): max_applied_limit is a text column but all values are integers, except for
            # the value "Unlimited" - this should probably be converted to a numeric type column / field (for es)
            indexes :max_applied_limit, type: 'keyword'
            indexes :coordinates, type: 'geo_point'
            indexes :publish_to_cs, type: 'boolean'
            indexes :account_manager_id, type: 'keyword'
            indexes :hiring_organization_type, type: 'keyword', normalizer: :lowercase
            # my job indexes
            indexes :visible_to_cs, type: 'boolean'
            indexes :account_managers, type: 'keyword', normalizer: :lowercase
            indexes :client_id, type: 'keyword'
            indexes :hiring_managers, type: 'keyword', normalizer: :lowercase
            indexes :hiring_watchers, type: 'keyword', normalizer: :lowercase
            indexes :hiring_organization_id, type: 'keyword'
            indexes :invited_agencies, type: 'keyword', normalizer: :lowercase
            indexes :recruiters, type: 'keyword', normalizer: :lowercase
            indexes :exclusive_access_end_time, type: 'date'
            indexes :agency_ids, type: 'keyword'
            indexes :billing_term_id, type: 'keyword'
            indexes :is_private, type: 'boolean'
            indexes :invited_to_ids, type: 'keyword'
            indexes :recommended_to_ids, type: 'keyword'
            indexes :job_score, type: 'float'
            indexes :applied_count, type: 'integer'
            indexes :applied_time, type: 'integer'
            indexes :applied_at, type: 'date'
            indexes :opened_at, type: 'date'
          end
        end
      end
    end

    def as_indexed_json(options = {})
      yoe = years_of_experience
      trns = stage_transitions.collect do |key, trn|
        [(Time.parse(key).to_f * 1000).to_i.to_s, trn['stage'].gsub(' ', '-')].join(':')
      end

      json = {
        id: id,
        address: address,
        city: city,
        country_obj_name: (country_obj ? (country_obj['name'] || '') : ''),
        country_obj_abbr: (country_obj ? (country_obj['abbr'] || '') : ''),
        state_obj: (state_obj ? (state_obj['name'] || '') : ''),
        state_obj_abbr: (state_obj ? (state_obj['abbr'] || '') : ''),
        created_at: created_at,
        currency: currency,
        currency_obj: currency_obj.as_json(only: [:name, :abbr]),
        pay_period: pay_period,
        pay_rate_min: suggested_pay_rate["min"],
        pay_rate_max: suggested_pay_rate["max"],
        published_at: published_at,
        opened_at: opened_at || published_at,
        ho_published_at: ho_published_at,
        on_hold_at: on_hold_at,
        closed_at: closed_at,
        stage: stage,
        is_private: is_private,
        summary: ActionView::Base.full_sanitizer.sanitize(summary),
        title: title,
        updated_at: updated_at,
        enable: enable,
        available_positions: available_positions,
        positions: positions,
        filled_positions: filled_positions,
        category_name: category ? category.name : '',
        industry_name: industry ? industry.name : '',
        duration: duration,
        is_remote: location_type == 'Remote',
        location_type: location_type,
        skills: skills.pluck(:name),
        timezone: timezone.as_json(only: [:abbr, :name]),
        type_of_job: type_of_job,
        postal_code: postal_code,
        job_id: job_id,
        cs_job_id: cs_job_id,
        display_job_id: display_job_id,
        years_of_experience: yoe.is_a?(Hash) ? yoe.values : [yoe],
        responsibilities: ActionView::Base.full_sanitizer.sanitize(responsibilities),
        preferred_qualification: ActionView::Base.full_sanitizer.sanitize(preferred_qualification),
        minimum_qualification: ActionView::Base.full_sanitizer.sanitize(minimum_qualification),
        additional_detail: ActionView::Base.full_sanitizer.sanitize(additional_detail),
        certifications: certifications,
        benefits: benefits,
        priority_of_status: priority_of_status,
        start_date: start_date,
        max_applied_limit: max_applied_limit,
        publish_to_cs: publish_to_cs,
        coordinates: { lat: latitude, lon: longitude },
        account_manager_id: account_manager_id,
        hiring_organization_type: (hiring_organization ? hiring_organization&.company_relationship : ''),
        archived_by_ids: affiliates.archived.pluck(:user_id),
        job_score: job_score,
        applied: talents_jobs.applied.count,
        stage_transitions: trns,
      }.merge(ES::Search.my_job_json(self, self))
      if stage == 'Open'
        json.merge!(
          invited_to_ids: affiliates.all_type_invitations.not_responded.active.pluck(:user_id),
          recommended_to_ids: distributions.not_responded.active.pluck(:user_id)
        )

        first_applied = metrics_stages.where(stage: 'Applied').order('created_at asc').first
        if first_applied
          json.merge!(
            applied_time: (first_applied.created_at.to_date - published_at.to_date).round,
            applied_at: first_applied.created_at
          )
        end
      else
        json.merge!(
          invited_to_ids: [],
          recommended_to_ids: []
        )
        if closed_at && published_at
          json.merge!(time_to_close: (closed_at.to_date - published_at.to_date).round)
        end
      end

      json
    end
  end
end
