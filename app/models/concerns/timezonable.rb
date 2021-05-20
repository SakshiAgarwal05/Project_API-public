module Concerns::Timezonable
  extend ActiveSupport::Concern

  included do
    include HTTParty

    belongs_to :timezone

    base_uri 'https://maps.googleapis.com'
  end

  module ClassMethods
    def determine_timezone(options)
      tz_code = options[:tz_code].nil? ? '' : options[:tz_code][1..-1]
      key = "#{options[:country]}-#{tz_code}"
      tz_id = nil
      tz_name = nil
      Rails.cache.fetch(key, expires_in: 365.days) do
        query = { lat: options[:lat], lng: options[:lng] }
        response = google_timezone(query)
        if response.code.eql?(200) && response['status'].eql?('OK')
          res = JSON.parse response.body
          tz_name = res['timeZoneName'].split[0...2]
          tz = Timezone.get_timezone_from_name(tz_name, tz_code)
          tz_id = tz.id if tz
        end
      end
      [tz_id, tz_name]
    end

    def google_timezone(query)
      query[:location] = "#{query.delete(:lat)},#{query.delete(:lng)}" if query[:lat] && query[:lng]
      query[:sensor] ||= false
      query[:timestamp] ||= 1331161200
      query[:key] = ENV['GOOGLE_API_KEY_TIMEZONE']
      Rails.logger.info query
      with_retries(max_tries: 3, base_sleep_seconds: 0.1, max_sleep_seconds: 2.0) do
        self.get('/maps/api/timezone/json', query: query)
      end
    end
  end
end
