class ShareLink < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include ES::ESShareLink
  belongs_to :created_by, class_name: 'User'
  belongs_to :shared, polymorphic: true
  belongs_to :agency

  has_many :shareables, dependent: :destroy

  before_create :generate_token

  scope :shared_urls, -> { where.not(shared_id: nil) }

  scope :visible_to, -> (login_user) {
    return none unless login_user.is_a?(User)

    if Role::COMMON_USED_ROLES.include?(login_user.primary_role)
      return where(nil)

    elsif login_user.hiring_org_user?
      return where(created_by_id: login_user.hiring_organization.user_ids)

    elsif login_user.agency_owner_admin? && login_user.agency.present?
      return where(
        agency_id: login_user.agency.affiliates.where(status: [:archived, :saved]).select(:agency_id)
      )

    elsif login_user.team_admin? && login_user.agency.present?
      team_user_ids = login_user.agency.affiliates.where(
        status: [:archived, :saved],
        user_id: login_user.my_team_users.select(:id)
      ).select(:user_id)

      return where(created_by_id: team_user_ids)

    elsif login_user.team_member? && login_user.agency.present?
      return where(
        created_by_id: login_user.affiliates.where(status: [:archived, :saved]).select(:user_id)
      )
    else
      return none
    end
  }

  private

  def generate_token
    self.token = SecureRandom.base58(12)
  end
end
