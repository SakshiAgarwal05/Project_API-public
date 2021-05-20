require 'csmm/match_maker'
module ModelCallback
  module CallbacksTalent
    def self.included(receiver)
      receiver.class_eval do
        before_validation :init_password, on: :create
        before_save :init_address
        before_validation :init_currency
        after_save :password_changed?, :notify_profile_status
        before_save :resume_parsed?
        after_save :update_resume_on_media
        before_destroy :check_if_disabled, prepend: true
        before_validation :add_primary_email
        before_validation :change_primary_email
        after_save :update_primary_email
        # set_profile_status must be before reset_status
        before_save :reset_status, :set_years_of_experience
        #after_save :check_profile_complete
        after_create_commit :start_resume_parsing
        #after_save :rename_file_as_talent_name
        after_save :add_record_to_resume
        before_validation :init_talent_preference, on: :create
        after_save :reindex_profiles
        after_save :create_talent_profile_on_confirm

        after_commit :handle_csmm_update
      end
    end

    def update_primary_email
      return unless changed.include?('confirmed_at') && confirmed?
      confirm_email(email)
    end

    def trigger_email
      return if added_by.present?
      return unless changed.include?('profile_status')
      return unless ['parsed', 'fail'].include?(profile_status)

      ResumeStatusMailer.send("send_resume_status_#{profile_status}", profile_status, self).deliver_later
    end

    def start_resume_parsing
      update_columns(profile_status: Talent::PROFILE_STATUS[:WAITING]) if resume_path.present?
      daxtra_upload
      convert_resume_pdf_upload_s3_async
      upload_candidate_info_s3
      update_profile_status
    end

    ########################
    private
    ########################

    def create_talent_profile_on_confirm
      SaveCandidateService.add_for_talent(self) if confirmed? && talent_profile_copy.nil?
    end

    def reindex_profiles
      ReindexObjectJob.set(wait: 5.seconds).perform_later(profiles.to_a)
    end

    def convert_resume_pdf_upload_s3_async
      return unless self['resume_path']

      ConvertResumeInPdfJob.set(wait: 10.seconds).perform_later(
        self['resume_path'],
        self.class.to_s,
        id
      )
    end

    def update_profile_status
      UpdateTalentParsingStatusJob.set(wait_until: 2.minute.from_now).perform_later(id) if resume_path
    end

    def upload_candidate_info_s3
      UploadTalentInfoS3Job.set(wait: 10.seconds).perform_later(id) if resume_path.present?
    end

    def reset_status
      self.status = get_status
    end

    # def rename_file_as_talent_name
    #   RenameFileJob.perform_now(self.class.to_s, self.id, true) if changed.include?('resume_path') && if_completed
    # end

    # def check_profile_complete
    #   return if if_completed || blank_fields.any?

    #   update_columns(if_completed: blank_fields.blank?)
    #   RenameFileJob.perform_now(self.class.to_s, self.id, resume_path.present?)
    # end

    def add_record_to_resume
      return unless resume_path.present?
      return unless changed.include?('resume_path')
      existing_resumes = resumes.where(resume_path: self['resume_path'])
      unless existing_resumes.present?
        resumes.find_or_create_by(
          resume_path: self['resume_path'],
          resume_path_pdf: self['resume_path_pdf'],
          master_resume: true
        )
      end
    end

    def check_if_disabled
      return true if !confirmed? && talents_jobs.active.empty?

      return true if !enable && talents_jobs.active.empty?

      errors.add(:base, I18n.t('talent.error_messages.active_jobs')) unless talents_jobs.active.empty?
      errors.add(:base, I18n.t('talent.error_messages.cannot_delete')) if enable
      throw(:abort)
    end

    def set_profile_status
      return unless resume_path.present?

      self.profile_status = Talent::PROFILE_STATUS[:WAITING]
    end

    def notify_profile_status
      if resume_path.present?
        Rails.logger.info '******* notify_profile_status *******'
        Rails.logger.info "resume_path.present? #{resume_path.present?}"
        Rails.logger.info "profile_status #{profile_status}"
        state_one = self.changed.include?('profile_status') &&
          [Talent::PROFILE_STATUS[:PARSED]].include?(profile_status) &&
          resume_path_pdf.present?
        state_two = self.changed.include?('profile_status') &&
          [Talent::PROFILE_STATUS[:FAIL]].include?(profile_status)
        
        trigger_email if state_one || state_two
      end
    end

    def resume_parsed?
      return unless changed.include?('resume')

      self.parse_resume = !resume.blank?
    end

    # After resume parsed, update it on media also.
    # CRWDPLT-770
    def update_resume_on_media
      return unless (changed.include?('resume_path') && resume_path.present?)

      media.create(file: self['resume_path'], title: "#{first_name}-resume", description: "Resume parsed!")
    end

    # Proifle save issue - Needed to send id for saving profile_status
    # because it is nested attribue
    def init_talent_preference
      currency = country.eql?('CA') ? 'CAD' : 'USD'
      self.build_talent_preference(currency: currency)
    end

    def handle_csmm_update
      return if Rails.env.development? || Rails.env.test?
      CsmmTaskHandlerJob.set(wait_until: 10.seconds.from_now).
        perform_later('handle_candidate_save', { candidate_id: id, _version: 2 })
    end
  end
end
