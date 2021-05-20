# Common methods for:
# * <tt>User</tt>
# * <tt>Talent</tt>
module AllUser

  # phone no can't be blank for candidates
  # phone no can't be blank for agency admin
  # phone no can't be blank for internal user while account confirmation
  # all users/candidate should have only one primary email.
  # all users/candidate should have only one primary phone.
  def atleast_one_primary_email
    if phones.size == 0 &&
      (is_a?(Talent) ||
        (is_a?(User) && confirming? && primary_role && internal_user?)
      )

      errors.add(:base, "Phone number can't be blank.")
    end
    errors.add(:base, "You can select only one primary email") if emails.where(primary: true).count > 1
    errors.add(:base, "You can select only one primary phone number") if phones.where(primary: true).count > 1
  end

  def validate_password
    return if password.blank?
    return if password.match(/[A-Z]/) &&
      password.match(/[a-z]/) &&
      password.match(/[!@#$&*]/) &&
      password.match(/[0-9]/) &&
      password.length >= 8
    errors.add(:password, "should contain at least 1 number, 1 special character, 1 upper and lower case with length 8 to 32.")
  end

  def change_primary_email
    add_primary_email if emails.where(primary: true).blank?
    return if self.is_a?(User)
    exist = emails.where(primary: true)
    return if exist.blank?
    return if email == exist[0].email
    self.email = exist.first.email
  end

  def add_primary_email
    emails.each { |obj| obj.email.try(:downcase!) } if emails.any?

    has_primary_email = emails.any? { |e| e.primary }
    unless has_primary_email
      existing_email = emails.where(email: email).first
      if existing_email
        existing_email.update_attributes(primary: true)
      else
        emails << Email.new(type: "Main", email: email, primary: true)
      end
    end
  end

  # Randomly generate password if it is not set. Only works for new users.
  # This is requires when someone invites a user to the system.
  def init_password(force = false)
    self.password = alphanumeric_password if password.blank? || force
    self
  end

  def alphanumeric_password
    (
      [*('a'..'z')].shuffle[8, 10] +
      [*('A'..'Z')].shuffle[8, 10] +
      ('0'..'9').to_a.shuffle[2, 4] +
      ['!','@','#','$','&','*'].shuffle[3, 6]
    ).shuffle.join
  end

  def add_detailed_errors
    existing_user = self.class.where(email: email).where.not(id: id).first
    return if existing_user.nil?
    errors.add(:base, 'Please reset your password if you forgot.') if existing_user.confirmed? && self.class.eql?(Talent)
    errors.add(:base, 'Your account is not yet confirmed. Request for a confirmation email for your account.') unless existing_user.confirmed?
  end

  def password_changed?
    return if is_a?(User) ||
      (!changed.include?("encrypted_password") &&
       !changed.include?("password")) ||
      (begin
         User.find(id)
       rescue
         nil
       end)
    password_set_by_user = true
    update_column(:password_updated_at, Time.now)
  end

  # full name of user
  def name
    [first_name, self['middle_name'], last_name].compact.join(' ')
  end

  # generates a auth token for login authentication.
  def auth_token(impersonater_id = nil)
    "#{self.class} " + JsonWebToken.encode(id, 24.hours.from_now, impersonater_id)
  end

  # using for omniauth.
  def email_verified?
    email && email !~ TEMP_EMAIL_REGEX
  end

  # linked in url
  def update_from_linked_in
    url = "https://api.linkedin.com/v1/people/~:(id,num-connections,picture-url,first-name,summary,location,languages,skills,certifications,educations,courses,three-current-positions,three-past-positions,date-of-birth)?format=json&oauth2_access_token=759624veeo03sg"
  end

  # send untead notifications
  # def send_notifications_in_email
  #   notifications = self.notifications.where(viewed_or_emailed: false)
  #   return if notifications.count.zero?
  #   NotificationMailer.notify_with_email(self, notifications).deliver
  # end

  def reset_password(new_password, new_password_confirmation)
    self.password = new_password
    self.password_confirmation = new_password_confirmation

    if respond_to?(:after_password_reset) && valid?
      ActiveSupport::Deprecation.warn "after_password_reset is deprecated"
      after_password_reset
    end
    save
  end

  def reset_password_for_user(mail=nil)
    if confirmed?
      send_reset_password_instructions_cs(mail)
      send_notification_for_user(['reset password'], LoggedinUser.current_user, LoggedinUser.user_agent) if is_a?(User)
      send_notification_for_talent(['reset password'], LoggedinUser.current_user, LoggedinUser.user_agent) if is_a?(Talent)
    else
      update_columns(updated_at: Time.now)
      resend_confirmation_instructions
      send_notification_for_user(['confirmation link'], LoggedinUser.current_user, LoggedinUser.user_agent) if is_a?(User)
      send_notification_for_talent(['confirmation link'], LoggedinUser.current_user, LoggedinUser.user_agent) if is_a?(Talent)
    end
  end

  def plural_name
    class_name.downcase.pluralize
  end

  def send_reset_password_instructions_cs(mail=nil)
    mail ||= email
    token = set_reset_password_token
    send_reset_password_instructions_notification_cs(mail, token)

    token
  end

  def send_reset_password_instructions_notification_cs(mail, token)
    send_devise_notification(:reset_password_instructions, token, {to: mail})
  end

  private

  # Generate username from firstname / lastname / email if it is not set. Only works for new users.
  # This is requires when someone invites a user to the system.
  def init_username #:doc:
    return if self.username || email.blank? || first_name.blank? || last_name.blank?
    chars = ('1'..'9').to_a+('A'..'Z').to_a
    sequencer = chars.repeated_permutation(2)
    strings = []
    (['']+('1'..'9').to_a+('A'..'Z').to_a).each{|i| strings << name.gsub(' ', '')+i}
    1296.times{ strings << name.gsub(' ', '')+sequencer.next.join } rescue nil
    strings = (strings - self.class.where(username: strings).collect(&:username)).sort
    self.username = strings.first
  end

  def class_name
    self.class.to_s
  end
end
