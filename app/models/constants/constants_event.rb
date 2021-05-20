# Constants
module Constants
  # ConstantsEvent
  module ConstantsEvent
    NEW_EVENT_TYPES = ['Onsite Interview', 'Phone Interview', 'Video Interview'].freeze
    EVENT_TYPES =
      NEW_EVENT_TYPES
    REPEAT = %w(Never Daily Weekly Bi-weekly Monthly).freeze

    TALENT_EMAIL_EVENT_STATUS = ['Scheduled', 'Cancelled', 'Confirmed', 'Requested'].freeze
  end
end
