# At many places we have addresses which need to be validated.
# This module provides common methods for vaidations.

module AddressValidations
  private

  # checks if postal code is valid for Canada or not
  def validate_canada_postal_code #:doc:
    self.postal_code = self.postal_code.upcase.gsub('-', ' ')
    self.postal_code = self.postal_code[0..2]+' '+self.postal_code[3..-1] if self.postal_code.length == 6
    self.errors.add(:postal_code, "should be 6 digit alphanumarec. Ex: H3G1B8 or H3G 1B8") if country == "CA" && (self.postal_code.nil? || !self.postal_code.match(/^[A-Z][0-9][A-Z][0-9][A-Z][0-9]|[A-Z][0-9][A-Z] [0-9][A-Z][0-9]$/))
  end

  # checks if postal code is valid for US or not
  def validate_us_postal_code #:doc:
    self.errors.add(:postal_code, "should be five digit number, with optional ZIP+4 section") if country == "US" && (self.postal_code.nil? || !self.postal_code.match(/^[0-9]{5}([-+]?[0-9]{4})?$/))
  end

  # checks if country and state are correct or not. city may be added in future.
  # also checks if format of postal code is correct or not if country is US or Canada.
  def validate_country_state_and_city #:doc:
    return if (self.changed & ["country", "state", "postal_code", "city"]).blank?
    init_address 
    if self.country_obj && ["US", "CA"].include?(country)
      begin
        unless state_obj && state_obj['id']
          errors.add(:state, I18n.t('user.error_messages.invalid_state'))
        end
        if self["postal_code"]
          #MISS(TODO: TEST CASES NOT WRITTEN)
          validate_canada_postal_code if country == "CA"
          validate_us_postal_code if country == "US"
        end
      rescue NoMethodError #MISS(TODO: TEST CASES NOT WRITTEN)
      end
    elsif self.country_obj.nil?
      self.errors.add(:country, "is invalid")
    end
  end

  # save association if address input exist in database.
  def init_address
    return if (changed & ['country', 'state', 'postal_code', 'city']).empty?
    do_init_address
  end

  def do_init_address
    c = Country.where(abbr: country).first
    self.country_obj = c.as_json(only: [:id, :name, :abbr])
    begin
      if c
        s = c.states.where(abbr: state).first
        self.state_obj = s ? s.as_json(only: [:id, :name, :abbr]) : { name: state, abbr: state, id: nil }
        ci =  s.cities.where(abbr: city).first if s
        self.city_obj = ci ? ci.as_json(only: [:id, :name, :abbr]) : {name: city, abbr: city, id: nil}
      end
    rescue NoMethodError
    end
    self
  end
end
