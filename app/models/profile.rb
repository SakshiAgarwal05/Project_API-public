class Profile < ApplicationRecord
  acts_as_paranoid

  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Fields::FieldsProfile
  include AddressValidations
  include ModelCallback::CallbacksProfile
  include Validations::ValidationsProfile
  include ES::ESProfile
  include AddAbility
  include CurrentUser
  include Concerns::Addressable

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

  cattr_accessor :current_user

  scope :my_candidates, -> { where(my_candidate: true) }

  scope :for_user, ->(user) {
    where(
      agency_id: user.agency_id,
      hiring_organization_id: user.hiring_organization_id,
      profilable_type: 'User'
    )
  }

  scope :for_talent, ->(talent) { where(talent: talent) }

  scope :my, ->(user) {
    return none unless user.is_a?(User)

    my_candidates = user.all_permissions['my candidates']
    return none if my_candidates.blank?

    where(
      agency_id: user.agency_id,
      hiring_organization_id: user.hiring_organization_id,
      profilable_type: 'User',
      my_candidate: true
    ).
      where.not(talent_id: nil)
  }

  scope :my_created, ->(user) { my(user).where(profilable_id: user.id) }

  scope :sortit, ->(order_field, order, current_user) {
    default_order = order || 'asc'
    case order_field
    when 'location'
      get_order(Arel.sql("
        profiles.country_obj->>'name',
        profiles.state_obj->>'name',
        profiles.city
      "), default_order)
    when 'first_name'
      get_order(
        Arel.sql("LOWER(profiles.first_name)"),
        default_order
      )
    when 'years_of_experience'
      get_order(
        Arel.sql("CAST(
          CONCAT(
          profiles.years_of_experience->>'years',
          '.',
          ABS(CAST(profiles.years_of_experience->>'months' as integer))
        ) as float)"),
        default_order
      )
    when 'created'
      get_order(Arel.sql("profiles.created_at"), default_order)
    when 'verified'
      joins(:talent).get_order(Arel.sql("talents.confirmed_at"), default_order)
    else
      get_order(Arel.sql("profiles.#{order_field}"), default_order)
    end
  }

  def send_destroy_notification(obj = nil)
    true
  end

  def avatar
    talent.avatar if talent
  end

  def image_resized
    talent.image_resized if talent
  end

  def if_available
    talent.if_available
  end

  def dummy?
    talent.dummy? if talent
  end

  def master_profile
    mp = talent.profiles.my_candidates.for_user(profilable).first rescue nil
    mp || self
  end

  def profile_related_objs
    { profile: { id: id, email: email, avatar: avatar, last_name: avatar, first_name: first_name }}
  end

  def status_for_enterprise
    return 'Not Available' if talent.blank?

    Talent::NOT_AVAILABLE.include?(talent.status) ? 'Not Available' : 'Available'
  end

  def name
    [first_name, self['middle_name'], last_name].compact.join(' ')
  end
end
