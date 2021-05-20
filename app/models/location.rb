class Location < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESLocation
  extend ES::SearchLocation

  include HTTParty

  validates :address, uniqueness: true

  has_many :events

  has_and_belongs_to_many :benefits
  has_and_belongs_to_many :talent_preferences

  def self.search_location(params={})
    locations, total_count = search_location_es(params)

    if locations.blank?
      search_location_google_places(params[:query])
    else
      [locations, total_count]
    end
  end

  def self.search_location_google_places(query)
    ids = []
    google_autocomplete = JSON.parse(
      HTTParty.get(
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=#{query}&language=en_US&types=(regions)&key=#{ENV['GOOGLE_API_KEY']}"
      ).body
    )

    google_autocomplete['predictions'].each do |prediction|
      place_id = prediction['place_id']
      google_location = JSON.parse(
        HTTParty.get(
          "https://maps.googleapis.com/maps/api/place/details/json?placeid=#{place_id}&key=#{ENV['GOOGLE_API_KEY']}"
        ).body
      )['result']
      location = self.new(address: google_location['formatted_address'])

      google_location['address_components'].each do |component|
        case component['types'][0]
        when 'country'
          location.country = component['long_name']
        when 'administrative_area_level_1'
          location.state = component['long_name']
        when 'administrative_area_level_2'
          location.city = component['long_name']
        end
      end

      location.save
      ids << location.id
    end

    locations = find(ids).sort { |x, y| ids.index(x.id) <=> ids.index(y.id) }
    [locations, locations.length]
  end

end
