require 'open-uri'
class Talent < ApplicationRecord
  # to be dropped in future
  HIDDEN_FIELDS = [
  ]

  include HiddenFields

  acts_as_paranoid
  extend Devise::Models
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include AllUser
  include AddAbility
  include GlobalID::Identification
  include AddressValidations

  include Fields::FieldsTalent
  include CustomDevise

  include ES::ESTalent
  include Constants::ConstantsTalent
  include Constants::ConstantsResume
  include CallbackResizeImage
  include ModelCallback::CallbacksTalent
  include Validations::ValidationsTalent
  include Notifiable
  include Scopes::ScopesTalent
  include CurrentUser
  include Concerns::Addressable
  include Concerns::CommonCsmmCallbacks
  # TODO: Temp commented to avoid HTTParty & mongoid
  # indexes issue.
  # include Timezonable

  def self.es_includes(options = {})
    [
      :languages,
      :experiences,
      :educations,
      :media,
      :links,
      :certifications,
      :phones,
      :emails,
      :resumes,
      :skills,
      :industries,
      :positions,
    ]
  end

  def self.reset_password_by_token(params)
    unless params[:reset_password_token].blank?
      reset_password_token = Devise.token_generator.
        digest(Talent, :reset_password_token, params[:reset_password_token])

      email = Email.where(confirmation_token: reset_password_token).first
      email.confirm! if email
    end
    super
  end

  def confirm_email(email)
    email.downcase! if email
    email_obj = emails.where(email: email).first
    if email_obj
      return if email_obj.confirmed?
      email_obj.confirm!
    else
      email_obj = emails.create!(email: email, type: 'Main')
      email_obj.confirm!
    end
  end

  def find_admins
    [self]
  end

  def active_jobs
    job_ids = talents_jobs.not_withdrawn.reached_at('Signed').pluck(:job_id)
    Job.where(id: job_ids)
  end

  # TODO: move to helper
  def current_position
    return {} if experiences.empty?
    experience = experiences.latest.first
    { title: experience.try(:title), company_name: experience.try(:company) }
  end

  # Elastic search should be used for this.
  def find_duplicates
    results = Talent.eager_load(:phones, :emails, profiles: :emails).
      where("talents.email in (:emails) OR
        phones.number in (:phones) OR
        (
          talents.first_name = :first_name AND
          talents.last_name = :last_name AND
          talents.country = :country AND
          talents.postal_code = :postal_code
        ) OR
        (
          profiles.first_name = :first_name AND
          profiles.last_name = :last_name AND
          profiles.country = :country AND
          profiles.postal_code = :postal_code
        ) OR
        emails.email in (:emails)",
        {
          emails: emails.collect{|model| model.email&.downcase},
          phones: phones.collect(&:number),
          first_name: first_name,
          last_name: last_name,
          country: country,
          postal_code: postal_code,
        }
      )
    id ? results.where("talents.id != ?", id) : results
  end

  def if_saved(user = nil)
    # to remove current_user after jbuilder refactor.
    user ||= current_user
    return false if user.nil?
    Talent.my_talents(user).where(id: id).exists?
  end

  def unsave(user)
    SaveCandidateService.remove(self, user)
    self
  end

  def talent_my_tabs(user)
    return {} unless Talent.my_talents(user).find(id) && user.all_permissions['my candidate tabs']
    Hash[user.all_permissions['my candidate tabs'].collect{|x| [x.downcase.gsub(' ', '_').to_sym, true]}]
  end

  def signed_talents_jobs
    talents_jobs.active.reached_at('Signed').order('talents_jobs.updated_at desc')
  end

  def show_status(job = nil, user = nil)
    return status if [
      'Hired',
      'Onboarding',
      'On Assignment',
      'Do Not Call',
      'Do Not Contact',
      'Disabled',
    ].include?(status)

    if job.present?
      tj_other = TalentsJob.where(job: job, talent: self).where.not(user: user).reached_at('Signed')
      tj_my = TalentsJob.where(job: job, talent: self, user: user).first
      return 'Engaged' if tj_other.any?
      return 'Available' unless tj_my
      return 'Disqualified' if tj_my.rejected?
      return 'Shortlisted' if tj_my.stage.eql?('Sourced')
      return tj_my.stage
    else
      status
    end
  end

  def if_available
    status.eql?('Available') || get_status.eql?('Available')
  end

  def get_status
    return 'Disabled' unless enable
    return 'Do Not Call' if !confirmed? && contact_by_email? && contact_by_phone.eql?(false)
    return 'Do Not Contact' if !confirmed? && do_not_contact
    if talents_jobs.active.where("stage": 'Assignment Begins').any?
      return 'On Assignment'
    elsif talents_jobs.active.where("stage": 'On-boarding').any?
      return 'Onboarding'
    elsif talents_jobs.active.where("stage": 'Hired').any?
      return 'Hired'
    else
      return 'Available'
    end
  end

  def if_editable(user)
    my_talents = user.all_permissions['actions my candidates'] || {}
    talent_pool = user.all_permissions['actions candidate pool'] || {}
    return true if talent_pool['update any candidate']
    return true if talent_pool['update unconfirmed available candidate'] &&
      !confirmed?
    return true if !verified &&
      my_talents['add new candidate'] &&
      added_by &&
      user.agency_id == added_by.agency_id
    false
  end

  def all_active_jobs(user)
    talents_jobs.
      includes(:job).
      not_rejected.
      not_withdrawn.
      visible_to(user).
      where.not(jobs: { stage: Job::STAGES_FOR_CLOSED })
  end

  def do_not_contact
    contact_by_email.eql?(false) && contact_by_phone.eql?(false)
  end

  def check_resume_change
    if resume_path.present?
      PdfService.convert_resume_pdf_upload_s3(self['resume_path'])
      upload_candidate_info_s3
      update_profile_status
    end
  end

  def update_parsing_status
    return if [Talent::PROFILE_STATUS[:NOT_APPLICABLE], Talent::PROFILE_STATUS[:PARSED]].include?(profile_status)

    if resume_path_pdf.present?
      if profile_status == Talent::PROFILE_STATUS[:WAITING]
        update_attributes(profile_status: Talent::PROFILE_STATUS[:FAIL])
      end
    else
      update_attributes(profile_status: Talent::PROFILE_STATUS[:NOT_APPLICABLE])
    end
  end

  def daxtra_upload
    return unless resume_path

    text = daxtra_text_file
    dir_name = Rails.configuration.tmp_path
    tmp_file_txt_path = create_txt_file(dir_name, text)
    s3_upload?("candidate-resumes/#{id}.txt", tmp_file_txt_path, ENV['DAXTRA_BUCKET_NAME'])
    delete_files(tmp_file_txt_path)
  end

  def create_upload_zip
    tmp_file = remsume_tmp_file(resume_path)
    original_file_name = resume_path.split('?').first.split('/').last
    ext = File.extname(original_file_name)
    rename_file(tmp_file.path, ext).eql?(0) unless ext.blank?

    renamed_file_path = "#{tmp_file.path}#{ext}"

    text = txt_file_template
    dir_name = Rails.configuration.tmp_path
    tmp_file_txt_path = create_txt_file(dir_name, text)

    tmp_file_zip_path = "#{dir_name}/#{id}.zip"
    create_zip(tmp_file_zip_path, tmp_file_txt_path, renamed_file_path)

    uploaded = s3_upload?("candidate-resumes/#{id}.zip",
                          tmp_file_zip_path, ENV['DAXTRA_BUCKET_NAME'])
    update_column(:daxtra_file_uploaded, Time.now)
    delete_files(tmp_file_txt_path, renamed_file_path, tmp_file_zip_path)
  end

  # Create zip from the file_paths given
  def create_zip(zipfile_name, *file_paths)
    Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
      file_paths.each do |filename|
        zipfile.add(File.basename(filename), filename)
      end
    end
  end

  # create text file
  def create_txt_file(dir_name, text)
    file_name = id
    tmp_file_txt_path = "#{dir_name}/#{file_name}.txt"
    File.open(tmp_file_txt_path, 'w') { |f| f.write(text) }
    tmp_file_txt_path
  end

  # Download candidate resume
  def remsume_tmp_file(resume_path)
    with_retries(:max_tries => 3, :base_sleep_seconds => 0.1, :max_sleep_seconds => 2.0,
                 :rescue => Exception) do
      stream = open(URI.parse(resume_path))
      return stream if stream.respond_to?(:path)

      Tempfile.new.tap do |file|
        file.binmode
        file.write stream.read
        stream.close
        file.rewind
      end
    end
  end

  # template for txt file
  def daxtra_text_file
    <<-EOL
    First Name: #{first_name}
    Middle Name: #{middle_name}
    Last Name: #{last_name}
    Country: #{country_obj ? country_obj['name'] : nil}
    State: #{state_obj ? state_obj['name'] : nil}
    Postal Code: #{postal_code}
    Phone: #{phones.first.number}
    Email: #{email}
    Candidate Id: #{id}
    resume_path: #{resume_path}
    EOL
  end

  # template for txt file
  def txt_file_template
    <<-EOL
    First Name: #{first_name}
    Middle Name: #{middle_name}
    Last Name: #{last_name}
    Country: #{country_obj ? country_obj['name'] : nil}
    State: #{state_obj ? state_obj['name'] : nil}
    Postal Code: #{postal_code}
    Phone: #{phones.first.number}
    Email: #{email}
    Candidate Id: #{id}
    EOL
  end

  #upload zip to S3
  def s3_upload?(key, file_path, bucket_name)
    s3 = Aws::S3::Resource.new
    obj = s3.bucket(bucket_name).object(key)
    uploaded = false
    with_retries(:max_tries => 3, :base_sleep_seconds => 0.1, :max_sleep_seconds => 2.0,
                 :rescue => Exception) do
      uploaded = obj.upload_file(file_path)
    end
    uploaded
  end

  # Deletes the files
  def delete_files(*file_paths)
    file_paths.each do |fp|
      File.delete(fp) if File.exist?(fp)
    end
  end

  # Rename file with extension given
  def rename_file(file_path, ext)
    FileUtils.mv( file_path, "#{file_path}#{ext}") unless ext.blank?
  end

  def create_pdf(file_path)
    result = false
    with_retries(:max_tries => 3, :base_sleep_seconds => 0.1, :max_sleep_seconds => 2.0,
                 :rescue => Exception) do
      Timeout::timeout(120) do
        result = system("unoconv -T 2 -f pdf #{file_path}")
        Rails.logger.info "Resume conversion result - #{result}"
      end
    end
    result
  end

  def can_invite?(user)
    user.can?(:create, TalentsJob) && if_available
  end

  class << self
    def send_confirmation_instructions(attributes = {})
      confirmable = find_by_unconfirmed_email_with_errors(attributes) if reconfirmable
      unless confirmable.try(:persisted?)
        confirmable = find_or_initialize_with_errors(confirmation_keys, attributes, :not_found)
      end
      confirmable.update_column(:send_emails, true) if confirmable.valid?
      confirmable.resend_confirmation_instructions if confirmable.persisted?
      confirmable
    end

    def upcoming_events_count(login_user, talent_ids)
      EventAttendee.where(
        talent_id: talent_ids,
        event_id: Event.visible_to(login_user).not_declined.confirmed_not_completed.map(&:id)
      ).group(:talent_id).count
    end

    def active_jobs_count(login_user, talent_ids)
      TalentsJob.
        where(talent_id: talent_ids, rejected: false, withdrawn: false).
        visible_to(login_user).
        for_open_jobs.
        distinct.
        group(:talent_id).
        count
    end
  end

  def full_name
    first_name.concat(" #{middle_name}").concat(" #{last_name}")
  end

  def temporary_auth_token
    "Temporary #{self.class.to_s} " + JsonWebToken.encode(self.id, 2.hours.from_now)
  end

  def any_signed_rtr?
    talents_jobs.reached_at('Signed').any?
  end

  def preferences_completed
    return false unless talent_preference
    talent_preference.completed
  end

  def profiles_not_applied
    jobs_not_applied = talents_jobs.where(interested: true, stage: 'Submitted') + talents_jobs.where(stage: ['Sourced', 'Invited'])
    return [] if jobs_not_applied.count.zero?
    jobs_not_applied.map(&:profile).compact
  end

  def update_self_applied_profiles
    profiles_not_applied.each do |profile_copy|
      common_att = Profile.attribute_names & Talent.attribute_names
      common_att.delete('id')
      common_att.each { |a| (profile_copy.update_columns(a => self[a])) rescue nil }
      profile_copy.update_attributes(skill_ids: skill_ids)
    end
  end

  def sync_with_updated_profile(current_profile)
    self.update_columns(
      first_name: current_profile.first_name,
      last_name: current_profile.last_name,
      middle_name: current_profile.middle_name,
      salutation: current_profile.salutation,
      sin: current_profile.sin,
      email: current_profile.email,
      timezone_id: current_profile.timezone_id,
      address: current_profile.address,
      city: current_profile.city,
      country_obj: current_profile.country_obj,
      country: current_profile.country,
      state_obj: current_profile.state_obj,
      state: current_profile.state,
      postal_code: current_profile.postal_code,
      summary: current_profile.summary
    )
  end

  def dnd_checkbox?
    !verified && talents_jobs.reached_at('Signed').count.zero?
  end

  def active_jobs_count
    talents_jobs.where(active: true).count
  end

  def get_profile_for(user)
    return nil unless user
    profiles.my_candidates.for_user(user).first
  end

  def editable_my_candidate(user)
    !verified && added_by &&
    user.agency_id == added_by.agency_id &&
    profiles.count <= 1 &&
    user.can?(:update, self)
  end

  def talent_profile_copy
    profiles.my_candidates.where(profilable: self).first
  end

  def update_contact_by
    return if contact_by_email && contact_by_phone
    self.contact_by_phone = true
    self.contact_by_email = true
    save(validate: false)
  end

  def active_talents_jobs(user)
    case user.role_group
    when 1
      talents_jobs.where(user_id: user.id)
    when 2
      talents_jobs.where(agency_id: user.agency_id)
    when 3
      talents_jobs.where(hiring_organization_id: user.hiring_organization_id)
    else
      talents_jobs.none
    end
  end

  # can be depricated
  def opportunities(login_user)
    matched_opportunities = Job.candidate_opportunities(self).
      where.not(id: active_talents_jobs(login_user).select(:job_id))
    matched_opportunities = matched_opportunities.my_jobs(login_user) if login_user.internal_user?
    matched_opportunities
  end

  def dummy?
    source == 'linkedin' || source == 'monster'
  end

  def upcoming_events_count(login_user)
    return 0 if event_attendees.count.zero?

    Event.
      where(id: event_attendees.select(:event_id)).
      visible_to(login_user).
      not_declined.
      confirmed_not_completed.
      count
  end

  def enterprise_opportunities(login_user)
    opportunities(login_user).
      where(hiring_organization_id: login_user.hiring_organization_id)
  end

  def enterprise_active_jobs(login_user)
    all_active_jobs(login_user).
      where(hiring_organization_id: login_user.hiring_organization_id)
  end

  def talents_jobs_for(login_user, job_id)
    talents_jobs.where(user_id: login_user.id, job_id: job_id).last
  end

  def talent_related_objs
    { talent: { id: id, email: email, avatar: avatar, last_name: last_name, first_name: first_name }}
  end
end
