module Concerns::Addressable
  extend ActiveSupport::Concern

  def self.included(receiver)
    receiver.class_eval do
      geocoded_by :full_address
      after_save :geocoding
    end
  end

  def full_address_changed?
    (address_changed? || city_changed? || state_changed? || country_changed?)
  end

  def full_address
    state = state_obj.present? ? state_obj['name'] : nil
    country = country_obj.present? ? country_obj['name'] : nil
    [address, city, state, country, postal_code].compact.join(', ')
  end

  def relative_address
    state = state_obj.present? ? state_obj['name'] : nil
    country = country_obj.present? ? country_obj['name'] : nil
    [city, state, country, postal_code].compact.join(', ')
  end

  def relative_address_without_city
    state = state_obj.present? ? state_obj['name'] : nil
    country = country_obj.present? ? country_obj['name'] : nil
    [state, country, postal_code].compact.join(', ')
  end

  def relative_address_without_state
    state = state_obj.present? ? state_obj['name'] : nil
    country = country_obj.present? ? country_obj['name'] : nil
    [country, postal_code].compact.join(', ')
  end

  def relative_address_without_postal_code
    state = state_obj.present? ? state_obj['name'] : nil
    country = country_obj.present? ? country_obj['name'] : nil
    [state, country].compact.join(', ')
  end

  def geocoding
    return unless full_address.present? && full_address_changed?
    change_in_timezone = self.is_a?(Talent) && (saved_change_to_state? || saved_change_to_country?)
    change_in_timezone = true if timezone_id.blank? || full_address_changed?
    GeocodingJob.set(wait_until: 5.second.from_now).
      perform_later(self.class.to_s, self.id, change_in_timezone)
  end
end
