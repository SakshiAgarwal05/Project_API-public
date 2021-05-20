# ====Fields<br>
# *_id* (BSON::ObjectId)<br>
# *deleted_at* (Time)<br>
# *type* (String)<br>
# *email* (String)<br>
# ------
# Saves emails for User, Talent, Contact
class Email < ApplicationRecord

  acts_as_paranoid

  attr_accessor :updated_by_id

  TYPES = ["Main", "Work", "Home", "Other"]

  validates :type, :email, presence: true
  validates :email, format:  Devise.email_regexp
  validates :type, inclusion: TYPES
  validate  :validate_uniqueness_of_email,
            :cannot_edit_verified_email,
            :can_be_primary

  after_save :after_save_update_talent
  before_destroy :can_destroy

  belongs_to :mailable, polymorphic: true
  # We have a column called type inherited from the old mongodb
  # database, but type is a reserved field for activerecrod, hence
  # this hack
  self.inheritance_column = '_not_using_it'

  def email=(val)
    self[:email] = val ? val.downcase : val
  end

  def validate_uniqueness_of_email
    return unless ['Profile', 'Talent'].include?(mailable_type)
    self.email = email

    duplicate = Talent.
      joins(:emails).
      where('emails.email = :email OR talents.email = :email', email: email).
      distinct

    duplicate_found = true if duplicate.size > 1

    duplicate_found = true if Email.where(email: email, mailable: mailable).where.not(id: id).any?

    errors.add(:email, 'is duplicate') if duplicate_found
  end

  def can_be_primary
    return unless mailable
    return unless primary && !confirmed && changed.include?('primary') &&
      mailable.emails.where(primary: true).where.not(confirmed_at: nil, id: id).any?

    errors.add(:base, "you can not make unverified email a primary email as primary email is already verified")
  end

  def can_destroy
    return unless confirmed?
    errors.add(:base, "you can not destroy a verified email")
    throw :abort
  end

  def cannot_edit_verified_email
    return true if new_record? || changed.blank? || mailable_id == updated_by_id
    return unless mailable.is_a?(Talent) && confirmed?
    self.errors.add(:base, "You can not edit email address of a verified candidate")
  end

  def confirmed?
    confirmed_at.present?
  end

  alias :confirmed :confirmed?

  def confirm!(sync_job: true)
    return if mailable.is_a?(User)
    primary = (
      mailable_type == 'Talent' &&
      !mailable.confirmed? &&
      mailable.emails.where(primary: true).where.not(id: id, confirmed_at: nil).blank?
    ) ||
    self.primary

    assign_attributes(
      confirmed_at: Time.now,
      confirmation_token: nil,
      confirmation_sent_at: nil,
      primary: primary
    )

    save(validate: false)
    SyncProfileService.sync_profile(self) if sync_job
  end

  def after_save_update_talent
    return unless ['Profile', 'Talent'].include?(mailable.class.to_s)
    return unless confirmed?
    return if mailable.is_a?(Talent) && mailable.confirmed?
    mailable.update_column(:email, email)
    mailable.is_a?(Talent) ? mailable.confirm : mailable.talent.confirm
    ReindexObjectJob.perform_now(mailable)
  end

end
