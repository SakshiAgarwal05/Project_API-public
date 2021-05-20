# common fields for talents and profiles
module Fields
  # FieldsTalentProfile
  module FieldsTalentProfile
    def self.included(receiver)
      receiver.class_eval do
        belongs_to :timezone
        belongs_to :matching_job_title

        has_many :languages, as: :embeddable
        has_many :experiences, as: :embeddable
        has_many :educations, as: :embeddable
        has_many :media, as: :mediable
        has_many :links, as: :embeddable
        has_many :certifications, as: :embeddable
        has_many :talents_jobs, dependent: :destroy, inverse_of: :talent
        has_many :notes, as: :notable
        has_many :phones, as: :callable, dependent: :destroy
        has_many :emails, as: :mailable, dependent: :destroy
        has_many :resumes, as: :uploadable, dependent: :destroy

        # skill industry and positions
        has_and_belongs_to_many :skills
        has_and_belongs_to_many :industries
        has_and_belongs_to_many :positions

        accepts_nested_attributes_for :languages, allow_destroy: true
        accepts_nested_attributes_for :experiences, allow_destroy: true
        accepts_nested_attributes_for :educations, allow_destroy: true
        accepts_nested_attributes_for :media, allow_destroy: true
        accepts_nested_attributes_for :links, allow_destroy: true
        accepts_nested_attributes_for :certifications, allow_destroy: true
        accepts_nested_attributes_for :phones, allow_destroy: true
        accepts_nested_attributes_for :emails, allow_destroy: true
        accepts_nested_attributes_for :resumes, allow_destroy: true

        alias_for_nested_attributes :phones=, :phones_attributes=
        alias_for_nested_attributes :emails=, :emails_attributes=
        alias_for_nested_attributes :languages=, :languages_attributes=
        alias_for_nested_attributes :experiences=, :experiences_attributes=
        alias_for_nested_attributes :educations=, :educations_attributes=
        alias_for_nested_attributes :media=, :media_attributes=
        alias_for_nested_attributes :links=, :links_attributes=
        alias_for_nested_attributes :certifications=, :certifications_attributes=
        alias_for_nested_attributes :resumes=, :resumes_attributes=

        before_save :set_years_of_experience
      end
    end

    def skill_ids=(val)
      begin
        fast_skill_ids_insert(val.reject(&:blank?))
      rescue
        super
      end
    end

    def position_ids=(val)
      begin
        fast_position_ids_insert(val.reject(&:blank?))
      rescue
        super
      end
    end

    def industry_ids=(val)
      begin
        fast_industry_ids_insert(val.reject(&:blank?))
      rescue
        super
      end
    end

    def set_years_of_experience
      total_days = self.experiences.sum { |p| p.worked_time ? p.worked_time : 0 }
      years = (total_days / 364.25).to_i
      total_days -= years * 364
      months = (total_days / 30).to_i
      total_days -= months * 30
      self.years_of_experience = { years: years, months: months, days: total_days }
    end

    ########################
    public
    ########################

    # copy profile
    def copy_profile(user=nil)
      profile = Profile.new
      Profile.attribute_names.each { |a| profile[a] = self[a] unless a == 'id' }
      profile.created_at = Time.now
      profile.updated_at = Time.now
      profile.my_candidate = false
      add_associations(profile, user)
      profile
    end

    def add_associations(profile, user)
      %w(
        educations
        experiences
        links
        languages
        certifications
      ).each do |associations|

        send(associations).each do |association|
          record = association.dup
          record.embeddable = nil
          profile.send(associations) << record
        end
      end

      phones.each do |phone|
        new_phone = phone.dup
        new_phone.callable = nil
        profile.phones << new_phone
      end

      emails.each do |email|
        new_email = email.dup
        new_email.mailable = nil
        profile.emails << new_email
      end

      media.each do |medium|
        new_medium = medium.dup
        new_medium.file = medium["file"]
        profile.media << new_medium
      end

      resumes.each do |resume|
        new_resume = resume.dup
        new_resume.uploadable = nil
        profile.resumes << new_resume
      end

      if self['resume_path'].present? &&
        profile.resumes.map { |cv| cv['resume_path'] }.exclude?(self['resume_path'])

        existing_resume = Resume.find_by(resume_path: self['resume_path'])

        if existing_resume.nil?
          new_resume = Resume.create(
            resume_path: self['resume_path'], resume_path_pdf: self['resume_path_pdf']
          )
        else
          new_resume = existing_resume.dup
          new_resume.uploadable = nil
        end

        new_resume.master_resume = true unless profile.resumes.pluck(:master_resume).include?(true)
        profile.resumes << new_resume
      end

      profile.skill_ids = skill_ids
      profile.industry_ids = industry_ids
      profile.position_ids = position_ids
    end

    def blank_fields
      fields = %w(
        first_name
        last_name
        emails
        phones
        city
        state
        country
        postal_code
        summary
      )

      fields.push('experiences', 'educations') if self['resume_path'].blank?
      fields.select { |field| field if self[field].blank? && try(field.to_sym).blank? }
    end

    # check if profile is complete or not.
    def complete
      if_completed
    end

    def associated_custom_validations
      experience_validation_errors if experiences
      education_validation_errors if educations
      link_validation_errors if links
      language_validation_errors if languages
      certification_validation_errors if certifications
    end

    def experience_validation_errors
      experiences.each do |experience|
        errors.add(:base, 'Please add a title.') if experience.title.blank?
        errors.add(:base, 'Please enter company name.') if experience.company.blank?
        errors.add(:base, "Please enter experience's start date.") if experience.start_date.blank?
        errors.add(:base, "Please add experience's end date.") if experience.end_date.blank? && experience.working.is_false?
        experience.dates_should_be_less_than_present_date
      end
    end

    def education_validation_errors
      educations.each do |education|
        errors.add(:base, 'Please enter a school.') if education.school.blank?
        errors.add(:base, 'Please enter a degree.') if education.degree.blank?
        education.dates_should_be_less_than_present_date
      end
    end

    def link_validation_errors
      links.each do |link|
        errors.add(:base, 'Please enter type of link.') if link.type.blank?
        errors.add(:base, 'Please enter a link.') if link.link.blank?
      end
    end

    def language_validation_errors
      languages.each do |language|
        errors.add(:base, 'Please enter name of the language.') if language.name.blank?
        errors.add(:base, 'Please enter proficiency of the language.') if language.proficiency.blank?
      end
    end

    def certification_validation_errors
      certifications.each do |certification|
        errors.add(:base, 'Please enter a certificate.') if certification.certificate_id.blank?
        errors.add(:base, 'Please enter a vendor.') if certification.vendor_id.blank?
      end
    end

    ######################
    private
    ######################

    def init_currency
      self.current_currency_obj = Currency.find_by(abbr: current_currency).as_json(only: [:id, :abbr, :name]) if current_currency
      self.expected_currency_obj = Currency.find_by(abbr: expected_currency).as_json(only: [:id, :abbr, :name]) if expected_currency
    end
  end
end
