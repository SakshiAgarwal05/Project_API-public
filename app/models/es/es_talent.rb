module ES
  module ESTalent

    def self.included(receiver)
      receiver.class_eval do
        index_name ES::ESCommon.indexify('talents')
        settings(
          index: ES::ESCommon.index_settings,
          analysis: ES::ESCommon.analysis
        ) do
          mapping '_source' => { :excludes => ['attachments'] } do
            indexes :id, type: 'keyword'
            indexes :status, type: 'keyword', normalizer: :lowercase
            indexes :name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :downcase_folding
            end
            indexes :previously_worked_at, type: 'keyword', normalizer: :lowercase
            indexes :currently_working_at, type: 'keyword', normalizer: :lowercase
            indexes :level_of_education, type: 'keyword', normalizer: :lowercase
            indexes :studied_at, type: 'keyword', normalizer: :lowercase
            indexes :skills, type: 'text', analyzer: :english
            indexes :industry_name, type: 'keyword', normalizer: :lowercase
            indexes :years_of_experience, type: 'double'
            indexes :summary, type: 'text', analyzer: :english
            indexes :address, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :city, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :country_obj_name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :country_obj_abbr, type: 'keyword', normalizer: :lowercase
            indexes :state_obj_name, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :state_obj_abbr, type: 'keyword', normalizer: :lowercase
            indexes :postal_code, type: 'keyword', normalizer: :lower_letters_and_digits_only
            indexes :emails, type: 'text', analyzer: :url do
              indexes :keyword, type: 'keyword'
              indexes :autocomplete, type: 'text', analyzer: :autocomplete, search_analyzer: :downcase_folding
            end
            indexes :phones, type: 'text', analyzer: :phone_number_search
            indexes :contact_by_phone, type: 'boolean'
            indexes :contact_by_email, type: 'boolean'
            indexes :relocate, type: 'boolean'
            indexes :work_authorization, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :sin, type: 'keyword', normalizer: :lowercase
            indexes :headline, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :languages, type: 'keyword'
            indexes :timezone, type: 'object' do
              indexes :abbr, type: 'keyword', normalizer: :lowercase
              indexes :name, type: 'text', analyzer: :downcase_folding
            end
            indexes :matching_job_title, type: 'text', analyzer: :downcase_folding do
              indexes :keyword, type: 'keyword'
            end
            indexes :created_at, type: 'date'
            indexes :coordinates, type: 'geo_point'

            indexes :attachments, type: :nested do
              indexes 'attachment.title', type: :text, store: true
              indexes 'attachment.author', type: :text, store: true
              indexes 'attachment.name', type: :text, store: true
              indexes 'attachment.date', type: :date, store: true
              indexes 'attachment.content_type', type: :text, store: true
              indexes 'attachment.content_length', type: :integer, store: true
              indexes 'attachment.content', term_vector: 'with_positions_offsets', type: :text, store: true
            end
          end
        end
      end
    end

    def as_indexed_json(options = {})

      json = {
        id: id,
        status: status,
        name: name,
        previously_worked_at: experiences.where(working: false).pluck(:company),
        currently_working_at: experiences.where(working: true).pluck(:company),
        level_of_education: educations.pluck(:degree),
        studied_at: educations.pluck(:school),
        skills: skills.pluck(:name),
        industry_name: talent_preference ? talent_preference.industries.pluck(:name) : [],
        years_of_experience: (
          years_of_experience['years'].to_f + (years_of_experience['months'].to_f/12) rescue 0.0
        ),
        summary: summary,
        city: city,
        country_obj_name: (country_obj ? (country_obj['name'] || '') : ''),
        country_obj_abbr: (country_obj ? (country_obj['abbr'] || '') : ''),
        state_obj_name: (state_obj ? (state_obj['name'] || '') : ''),
        state_obj_abbr: (state_obj ? (state_obj['abbr'] || '') : ''),
        postal_code: postal_code,
        emails: [email] + emails.pluck(:email),
        phones: phones.pluck(:number),
        contact_by_phone: contact_by_phone,
        contact_by_email: contact_by_email,
        relocate: willing_to_relocate,
        work_authorization: work_authorization,
        sin: sin,
        headline: headline,
        languages: languages.pluck(:name).compact,
        timezone: timezone.as_json(except: [:id]),
        matching_job_title: matching_job_title,
        created_at: created_at,
        coordinates: { lat: latitude, lon: longitude },
      }

      attachments = []
      resumes.order(if_primary: :desc, created_at: :desc).limit(1).each do |resume|
        begin
          file = CsFile.new(resume.resume_path)
          attachments << { data: file.base64_encode }
        rescue
          nil
        end
      end

      json.merge!({ attachments: attachments }) if attachments.present?

      json
    end
  end
end
