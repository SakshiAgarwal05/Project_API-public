module ES
  module ESTalentsJob

    def self.included(receiver)
      receiver.class_eval do
        index_name ES::ESCommon.indexify('talents_jobs')
        settings(
          index: ES::ESCommon.index_settings,
          analysis: ES::ESCommon.analysis
        ) do
          mapping do
            indexes :id, type: 'keyword'
            indexes :job_id, type: 'keyword'
            indexes :user_id, type: 'keyword'
            indexes :talent_id, type: 'keyword'
            indexes :client_name, type: 'text' do
              indexes :keyword, type: 'keyword'
            end
            indexes :cs_job_id, type: 'text' do
              indexes :keyword, type: 'keyword', normalizer: :lower_letters_and_digits_only
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :lower_letters_and_digits_search
              indexes :autocomplete_ngram, type: 'text', analyzer: :autocomplete_ngram
            end
            indexes :job_job_id, type: 'text' do
              indexes :keyword, type: 'keyword', normalizer: :lower_letters_and_digits_only
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :lower_letters_and_digits_search
              indexes :autocomplete_ngram, type: 'text', analyzer: :autocomplete_ngram
            end
            indexes :display_job_id, type: 'text' do
              indexes :keyword, type: 'keyword', normalizer: :lower_letters_and_digits_only
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :lower_letters_and_digits_search
              indexes :autocomplete_ngram, type: 'text', analyzer: :autocomplete_ngram
            end
            indexes :account_managers, type: 'keyword', normalizer: :lowercase
            indexes :client_id, type: 'keyword'
            indexes :hiring_managers, type: 'keyword', normalizer: :lowercase
            indexes :hiring_watchers, type: 'keyword', normalizer: :lowercase
            indexes :hiring_organization_id, type: 'keyword'
            indexes :active, type: 'boolean'
            indexes :rejected, type: 'boolean'
            indexes :withdrawn, type: 'boolean'
            indexes :stage, type: 'keyword', normalizer: :lowercase
            indexes :created_at, type: 'date'
            indexes :updated_at, type: 'date'
            indexes :job_title, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :job_city, type: 'text', analyzer: :downcase_folding
            indexes :job_state_obj, type: 'object' do
              indexes :id, type: 'keyword'
              indexes :abbr, type: 'keyword', normalizer: :lowercase
              indexes :name, type: 'text', analyzer: :downcase_folding
            end
            indexes :job_country_obj, type: 'object' do
              indexes :id, type: 'keyword'
              indexes :abbr, type: 'keyword', normalizer: :lowercase
              indexes :name, type: 'text', analyzer: :downcase_folding
            end
            indexes :job_postal_code, type: 'keyword', normalizer: :lower_letters_and_digits_only
            indexes :category_name, type: 'keyword', normalizer: :lowercase
            indexes :category_id, type: 'keyword'
            indexes :industry_id, type: 'keyword'
            indexes :job_stage, type: 'keyword', normalizer: :lowercase
            indexes :visible_to_cs, type: 'boolean'
            indexes :hiring_managers, type: 'keyword'
            indexes :hiring_watchers, type: 'keyword'
            indexes :billing_term_id, type: 'keyword'
            indexes :type_of_job, type: 'keyword', normalizer: :lowercase
            indexes :name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :emails, type: 'text', analyzer: :url
            indexes :phones, type: 'text', analyzer: :phone_number_search
            indexes :tags, type: 'text', analyzer: :english
            indexes :work_authorization, type: 'text', analyzer: :english
            indexes :talent_city, type: 'text', analyzer: :downcase_folding
            indexes :sort_order, type: 'float'
            indexes :talent_state_obj, type: 'object' do
              indexes :id, type: 'keyword'
              indexes :abbr, type: 'keyword', normalizer: :lowercase
              indexes :name, type: 'text', analyzer: :downcase_folding
            end
            indexes :talent_country_obj, type: 'object' do
              indexes :id, type: 'keyword'
              indexes :abbr, type: 'keyword', normalizer: :lowercase
              indexes :name, type: 'text', analyzer: :downcase_folding
            end
            indexes :talent_postal_code, type: 'keyword', normalizer: :lower_letters_and_digits_only
            indexes :talent_address, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :recruiter_name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :recruiter_username, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :recruiter_agency_name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :assignment_end_date, type: 'date'
          end
        end
      end
    end

    def as_indexed_json(options = {})
      json = {
        id: id,
        user_id: user_id,
        agency_id: agency_id,
        active: active,
        rejected: rejected,
        withdrawn: withdrawn,
        stage: stage,
        created_at: created_at,
        updated_at: updated_at,
        sort_order: sort_order,
      }

      json.merge!(assignment_end_date: assignment_detail.end_date) if assignment_detail
      if job
        json.merge!({
          job_id: job.id,
          job_title: job.title,
          job_job_id: job.job_id,
          cs_job_id: job.cs_job_id,
          display_job_id: job.display_job_id,
          job_city: job.city,
          job_state_obj: job.state_obj,
          job_country_obj: job.country_obj,
          job_state_obj_abbr: job.state_obj['abbr'],
          job_postal_code: job.postal_code,
          job_country_obj_name: job.country_obj['name'],
          job_country_obj_abbr: job.country_obj['abbr'],
          job_stage: job.stage,
          type_of_job: job.type_of_job,
        })
        json.merge!(ES::Search.my_job_json(job, self))
      end
      if profile
        json.merge!({
          name: profile.name,
          emails: profile.emails.pluck(:email),
          phones: profile.phones.pluck(:number),
          tags: profile.master_profile.tags.pluck(:name),
          work_authorization: profile.work_authorization,
          talent_city: profile.city,
          talent_state_obj: profile.state_obj,
          talent_country_obj: profile.country_obj,
          talent_state_obj_abbr: profile.state_obj['abbr'],
          talent_postal_code: profile.postal_code,
          talent_country_obj_name: profile.country_obj['name'],
          talent_country_obj_abbr: profile.country_obj['abbr'],
          talent_address: profile.address,

        })
        # json.merge!(ES::Search.my_profile_json(profile, self))
      end
      if user
        json.merge!({
          recruiter_name: user.name,
          recruiter_username: user.username,
          recruiter_agency_name: user.agency_user? ? user.agency&.company_name : 'Crowdstaffing',
        })
      end
      json
    end
  end
end

