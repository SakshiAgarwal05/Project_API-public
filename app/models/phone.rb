# ====Fields<br>
# *_id* (BSON::ObjectId)<br>
# *deleted_at* (Time)<br>
# *type* (String)<br>
# *number* (String)<br>
# ------
# Saves emails for User, Talent, Contact
class Phone < ApplicationRecord
  acts_as_paranoid

  attr_accessor :updated_by_id

  TYPES = ["Main", "Home", "Work", "Personal Mobile", "Work Mobile", "Home Fax", "Work Fax", "Pager", "Other"]

  validates :type, :number, presence: true,
            unless: proc { |obj| obj.callable.is_a?(Contact) }

  validates :type, inclusion: TYPES
  validate  :cannot_edit_verified_phone,
            :can_be_primary
  belongs_to :callable, polymorphic: true
  
  after_save :set_contact_no
  before_destroy :can_destroy

  self.inheritance_column = '_not_using_it'

  def can_be_primary
    return unless callable
    return unless primary && !confirmed && changed.include?('primary') && 
      callable.phones.where(primary: true, confirmed: true).where.not(id: id).any?

    errors.add(:base, "you can not make unverified phone a primary phone as primary phone is already verified")
  end

  def set_contact_no
    SyncProfileService.sync_profile(self) if confirmed && changed.include?('confirmed')
    return unless primary && callable_type == 'User' && number != callable.contact_no
    callable.update_column(:contact_no, number)
  end

  def cannot_edit_verified_phone
    return true if new_record? || changed.exclude?('number') || callable_id == updated_by_id
    errors.add(:base, 'You can not edit a verified phone number') if confirmed?
  end

  def can_destroy
    return unless confirmed?
    errors.add(:base, "you can not destroy a verified email")
    throw :abort
  end

  def confirm!(sync_job: true)
    # return if confirmed
    self.confirmed = true
    save(validate: false)
  end
end
