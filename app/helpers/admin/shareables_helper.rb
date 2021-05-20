module Admin
  module ShareablesHelper
    def source_candidate_power(shareable)
      (shareable.available? || shareable.my_candidate?) &&
        check_users(current_user, shareable.user)
    end

    def view_talent_profile(shareable)
      my = get_talent_profile(shareable).present?

      tjs = TalentsJob.
        where(
          talent_id: shareable.talent_id,
          job_id: shareable.job_id,
          user_id: current_user.id
        ).
        exists?

      ((shareable.sourced? && tjs) || my) && check_users(current_user, shareable.user)
    end

    def save_candidate_power(shareable)
      !view_talent_profile(shareable) &&
        check_users(current_user, shareable.user) &&
        shareable.available?
    end

    def decline_power(shareable)
      shareable.available? && check_users(current_user, shareable.user)
    end

    def undo_declined_power(shareable)
      shareable.declined? && check_users(current_user, shareable.user)
    end

    def check_users(current_user, shareable_user)
      if current_user.internal_user? && shareable_user.internal_user?
        true
      elsif current_user.agency.present? &&
          shareable_user.agency.present? &&
          shareable_user.agency_id.eql?(current_user.agency_id)

        true
      elsif current_user.hiring_org_user? &&
          shareable_user.hiring_org_user? &&
          shareable_user.hiring_organization_id.eql?(current_user.hiring_organization_id)
        true
      else
        false
      end
    end

    def get_talent_profile(shareable)
      Profile.
        where(
          my_candidate: true,
          profilable_id: current_user.id,
          agency_id: current_user.agency_id,
          talent_id: shareable.talent_id
        ).
        last
    end

    def view_pipeline(shareable)
      shareable.sourced? &&
        (
          current_user.internal_user? ||
          shareable.user.agency_id == current_user.agency_id ||
          shareable.user.agency_id == current_user.hiring_organization_id
        )
    end
  end
end
