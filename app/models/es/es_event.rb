module ES
  module ESEvent
    def self.included(receiver)
      receiver.class_eval do
        index_name ES::ESCommon.indexify('events')
        settings(
          index: ES::ESCommon.index_settings,
          analysis: ES::ESCommon.analysis
        ) do
          mapping do
            indexes :id, type: 'keyword'
            indexes :title, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :downcase_folding
            end
            indexes :job_title, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :downcase_folding
            end
            indexes :job_id, type: 'keyword'
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
            indexes :event_type, type: 'keyword', normalizer: :lowercase
            indexes :requested, type: 'boolean'
            indexes :user_id, type: 'keyword'
            indexes :attendees, type: 'keyword'
            indexes :attendee_emails, type: 'keyword', normalizer: :lowercase
            indexes :title, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :start_date_time, type: 'date'
            indexes :end_date_time, type: 'date'
            indexes :declined, type: 'boolean'
            indexes :active, type: 'boolean'
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
            indexes :industry_id, type: 'keyword'
            indexes :category_id, type: 'keyword'
          end
        end
      end
    end

    def as_indexed_json(options = {})
      json = {
        id: id,
        title: title,
        event_type: event_type,
        requested: !confirmed && request,
        confirmed: confirmed,
        user_id: user_id,
        attendees: (event_attendees.pluck(:user_id) + event_attendees.pluck(:talent_id)).flatten.compact.uniq,
        attendee_emails: event_attendees.pluck(:email),
        declined: declined,
        start_date_time: start_date_time,
        end_date_time: end_date_time,
        expire_at: time_slots.any? ? time_slots.maximum(:end_date_time) : nil,
        active: active
      }
      if job
        json.merge!({
          job_id: job.id,
          job_title: job.title,
          job_job_id: job.job_id,
          cs_job_id: job.cs_job_id,
          display_job_id: job.display_job_id,
          industry_id: job.industry_id,
          category_id: job.category_id,
        })
        json.merge!(ES::Search.my_job_json(job, self))
      end
      json
    end
  end
end
