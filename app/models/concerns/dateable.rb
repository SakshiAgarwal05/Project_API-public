module Dateable
  extend ActiveSupport::Concern

  def computed_end_date
    duration = self.duration.to_f
    result = {
      years: (duration * 365.25).days,
      months: (duration * 30).days,
      weeks: (duration * 7).days,
      days: (duration * 24).hours,
      hours: (duration * 60).minutes
    }.with_indifferent_access

    end_date = (start_date + result[duration_period]).to_time.utc
  end
end
