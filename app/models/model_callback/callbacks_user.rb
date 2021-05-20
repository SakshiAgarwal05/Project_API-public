require 'csmm/match_maker'
module ModelCallback
  module CallbacksUser
    def self.included(receiver)
      receiver.class_eval do
        # assign all the available permission based on assigned roles to user.
        before_validation :init_role
        before_validation :init_password, on: :create
        before_validation :init_username
        # before_validation :username_if_editable
        before_validation :init_address
        before_validation :add_primary_email
        before_validation :change_primary_email
        before_validation :init_address_for_agency_users

        before_destroy :handle_referenced_records

        before_save :save_show_status

        after_update :recommend_jobs_new_recruiter, if: :request_recommendations

        after_destroy :update_agency_categories

        after_commit :show_to_rectricted_access, :show_to_exclusive_access, on: :create
        after_commit :create_phones, on: :update
        after_commit :update_agency_categories, on: [:update, :destroy]
        after_commit :handle_csmm_update
        after_commit :check_verification, on: :update
      end
    end

    # can not delete a user if some candidate still signed RTR with that user.
    def before_destroy_checklist
      if enable && destroyed_by_association.blank?
        errors.add(:base, "Can't delete a enabled user.")
      end
      errors.add(:base, 'Can not delete this user.') if email.eql?("sunil@crowdstaffing.com")

      if (agency_owner? || agency_admin?) && destroyed_by_association.blank?
        errors.add(:base, 'agency owner or agency admin cannot delete')
      end

      unless talents_jobs.reached_at('Signed').active.count.zero?
        errors.add(
          :base,
          I18n.t('user.error_messages.pipeline_representer', first_name: first_name)
        )
      end

      self
    end

    def destroy
      before_destroy_checklist
      case primary_role
      when 'enterprise manager', 'enterprise member', 'team admin', 'team member'
        errors.present? ? false : really_destroy!
      else
        errors.present? ? false : super
      end
    end

    def delete
      before_destroy_checklist
      case primary_role
      when 'enterprise manager', 'enterprise member', 'team admin', 'team member'
        errors.present? ? false : delete!
      else
        errors.present? ? false : super
      end
    end

    ########################

    public

    ########################

    def init_address_for_agency_users
      return unless agency
      return if !agency.if_valid? || city? || state || country || postal_code
      self.city = agency.city
      self.state = agency.state
      self.country = agency.country
      self.postal_code = agency.postal_code
    end

    def create_phones
      return if contact_no.blank? || phones.where(number: contact_no).any?
      phones.create(primary: true, number: contact_no, type: 'Work', extension: extension)
    end

    # copy all permissions to user defined for the role assigned.
    def init_role
      self.timezone_id = Timezone.find_by_abbr('PST') unless timezone_id
      self.role_group = Role::GET_GROUP[primary_role]
    end

    def update_agency_categories
      return unless agency&.if_valid?
      agency.save_agency_expertise
    end

    ########################

    private

    ########################

    def check_verification
      if confirmed_at.present? && verified_at.blank? && incompleted_profile.blank?
        update_columns(verified_at: Time.now)
      end
    end

    def recommend_jobs_new_recruiter
      CsmmTaskHandlerJob.perform_now(
        'recommend_10_jobs_new_recruiter',
        { recruiter_id: id,  _version: 2 }
      )
    end

    def save_show_status
      self.show_status = get_status
    end

    def handle_csmm_update
      return if Rails.env.development? || Rails.env.test?
      return unless agency_user?
      CsmmTaskHandlerJob.set(wait: 10.seconds).
        perform_later('handle_recruiter_save', { recruiter_id: id, _version: 2 })
    end

    def handle_referenced_records
      owner = case primary_role
              when 'enterprise manager', 'enterprise member'
                hiring_organization.owner
              when 'team admin', 'team member'
                agency.owner_or_admin
              end
      if owner.present?
        Event.where(user_id: id).update_all(user_id: owner.id)
        Note.where(user_id: id).update_all(user_id: owner.id)
      end
    end

    def show_to_rectricted_access
      ShowToRestrictedAccessJob.set(wait: 10.seconds).perform_later('users', id)
    end

    def show_to_exclusive_access
      ShowToExclusiveAccessJob.set(wait: 10.seconds).perform_later('users', id)
    end
  end
end
