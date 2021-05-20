module Validations
  module ValidationsNote
    def self.included(receiver)
      receiver.class_eval do
        validates :note, :user, :visibility, presence: true
        validates :visibility,
                  inclusion: Note::CROWDSTAFFING_VISIBILITY,
                  if: proc { |n| n.user&.internal_user? }

        validates :visibility,
                  inclusion: Note::TS_VISIBILITY,
                  if: proc { |n| n.user&.agency_user? }

        validates :visibility,
                  inclusion: Note::HO_VISIBILITY,
                  if: proc { |n| n.user&.hiring_org_user? }
      end
    end
  end
end
