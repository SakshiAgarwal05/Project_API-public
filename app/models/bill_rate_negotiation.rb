class BillRateNegotiation < ApplicationRecord
  validates :value, presence: true

  belongs_to :approved_by, class_name: 'User'
  belongs_to :new_bill_rate, class_name: 'BillRateNegotiation', foreign_key: :proposed_bill_rate_id
  belongs_to :proposed_by, class_name: 'User'
  belongs_to :rejected_by, class_name: 'User'
  belongs_to :rtr

  has_one :declined_rate, class_name: 'BillRateNegotiation', foreign_key: :proposed_bill_rate_id
  has_one :talents_job, through: :rtr, source: :talents_job

  has_many :read_bill_rates, dependent: :destroy
  has_many :read_rate_by, through: :read_bill_rates, source: :user

  after_save :new_proposed_bill_rate

  def get_status(user)
    if approved_by_id.blank? && rejected_by_id.blank?
      "waiting"
    elsif rejected_by_id.present?
      rejected_by_id != user.id && status.eql?('Declined') ? "declined" : "new"
    elsif approved_by_id.present? && (approved_by_id != user.id)
      "approved"
    else
      "new"
    end
  end

  def read_bill_rate_by(user)
    read_by_user = user_for_acknowledgement(user)
    read_by_user.present? ? read_rate_by.where(id: read_by_user.id).exists? : false
  end

  def user_for_acknowledgement(user)
    if user.internal_user?
      talents_job.job.account_manager
    elsif user.agency_user?
      talents_job.user
    elsif user.hiring_org_user?
      talents_job.job.hiring_manager.present? ? talents_job.job.hiring_manager : user
    end
  end

  private

  def new_proposed_bill_rate
    return unless changed.include?('if_declined_and_proposed')
    rtr.bill_rate_negotiations.order(updated_at: :desc).
      where(rejected_by_id: proposed_by_id, status: 'Declined').first.
      update_column(:proposed_bill_rate_id, id)
  end
end
