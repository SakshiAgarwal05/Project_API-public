class EventAttendee < ApplicationRecord
  acts_as_paranoid
  include Scopes::ScopesEventAttendee
  include Validations::ValidationsEventAttendee
  include ModelCallback::CallbacksEventAttendee

  belongs_to :event
  belongs_to :user, optional: true
  belongs_to :talent, optional: true

  def first_name
    return user.first_name if user
    return talent.first_name if talent
  end

  def middle_name
    return user.middle_name if user
    return talent.middle_name if talent
  end

  def last_name
    return user.last_name if user
    return talent.last_name if talent
  end

  def name
    return user.name.titleize if user
    return talent.name.titleize if talent
    email
  end

  def avatar
    return user.avatar if user
    return talent.avatar if talent
  end

  def primary_role
    user.primary_role if user
  end

  def can_send_message(user)
    return false if user_id.nil? && talent_id.nil? # cannot message external user
    return true if user.internal_user? # internal user can message any user
    if user.agency_user? || user.hiring_org_user?
      valid_emails = User.message_valid_users(user).pluck(:email) + Profile.my(user).pluck(:email)
      valid_emails.include?(email) ? true : false
    end
  end
end
