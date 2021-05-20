  # ====Fields<br>
# *_id* (BSON::ObjectId)<br>
# *deleted_at* (Time)<br>
# *name* (String)<br>
# *abbr* (String)<br>
# *value* (String)<br>
# ------
class Timezone < ApplicationRecord
  acts_as_paranoid
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  include ES::ESTimezone
  extend ES::SearchTimezone

  include HTTParty
  validates :name, :abbr, :value, presence: true
  validates :abbr, uniqueness: { scope: :name }

  # Delete Cache timezones redis cache after update
  after_save{ Rails.cache.delete("timezones")}
  after_destroy{ Rails.cache.delete("timezones")}
  scope :truncated, ->{where(truncated: true)}

  # Low Level caching added for timezones
  class << self # please define class methods here.
    def cached_timezones
      Rails.cache.fetch("timezones", expires_in: 1.month) do
        Timezone.order(:name)
      end
    end

    def truncated_timezones
      Rails.cache.fetch("truncated_timezones", expires_in: 1.month) do
        Timezone.truncated.order("name asc")
      end
    end

    def get_timezone_from_name(tz_name, tz_code)
      self.find_by("name ~= ? AND value ~= ?", tz_name.join(' '), tz_code) ||
        self.find_by("name ~= ?", tz_name.join(' ')) ||
        self.find_by("name ~= ?", tz_name.first)
    end

    def determine_timezone(options)
      key = "tz-#{options[:country]}-#{options[:state]}"
      tz_id = Rails.cache.read(key)
      if tz_id.blank?
        response = google_timezone({ location: options[:location] })
        if response.code.eql?(200) && response['status'].eql?('OK')
          res = JSON.parse response.body
          tz_name = res['timeZoneName']
          tz = Timezone.find_by("name ~* ? ", "^#{tz_name}") ||
            Timezone.find_by("name ~* ? ", tz_name)
          if tz
            tz_id = tz.id
            Rails.cache.write(key, tz_id, expires_in: 365.days)
          elsif Rails.env.production?
            ActionMailer::Base.mail(
              from: "'Crowdstaffing'<noreply@crowdstaffing.com>",
              to: 'suratp@zenithtalent.com, nikitag@crowdstaffing.com',
              subject: 'Timezone not found',
              body: "#{tz_name} not found in database"
            ).deliver_later
          end
        end
        tz_id
      end
      tz_id
    end

    def google_timezone(query)
      query[:sensor] ||= false
      query[:timestamp] ||= 1331161200
      query[:key] = ENV['GOOGLE_API_KEY_TIMEZONE']
      Rails.logger.info query
      with_retries(max_tries: 3, base_sleep_seconds: 0.1, max_sleep_seconds: 2.0) do
        self.get('https://maps.googleapis.com/maps/api/timezone/json', query: query, :verify => false)
      end
    end
  end # END of Class methods.

  def dst_start_date
    return nil unless if_dst
    dst = dst_start_day.split(' ')
    date = get_time_chronic(dst_start_day, true)
    if date > dst_end_date
      date = get_time_chronic(dst_start_day, false)
    end
    date
  end

  def dst_end_date
    return nil unless if_dst
    get_time_chronic(dst_end_day, true)
  end

  def get_time_chronic(date_string, if_next=true)
    date_string, hours_before = date_string.split(" - ")
    attach_string = if_next ? ' of next ' : ' of last '
    if date_string.match(/last sunday/)
      dst = date_string.gsub('last sunday', 'last day' + attach_string)
      date = Chronic.parse('last sunday', now: Chronic.parse(dst))
    else
      dst = date_string.split(' ')
      if attach_string == ' of next ' && dst[-1].downcase == Date.today.strftime('%B').downcase
        dst = dst[0..-2].join(' ') + 'of this month'
      else
        dst = dst[0..-2].join(' ') + attach_string + dst[-1]
      end
      date = Chronic.parse(dst)
    end
    date -= eval(hours_before) if hours_before
    date
  end

  def apply_dst?(time)
    return nil unless if_dst
    time > dst_start_date && time < dst_end_date
  end

  def get_dst_time(time_in_utc)
    zone_offset = self.value.split('UTC')[-1]||"00:00"
    if zone_offset
      zone_offset+=":00" if zone_offset.index(':').nil?
      zone_offset[0]="-" if zone_offset[0].ord==8722
    end
    time = time_in_utc + Time.zone_offset(zone_offset) unless Time.zone_offset(zone_offset).nil?
    apply_dst?(time) ? time + 1.hour : time
  end
end
