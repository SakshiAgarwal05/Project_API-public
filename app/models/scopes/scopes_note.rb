module Scopes
  module ScopesNote
    def self.included(receiver)
      receiver.class_eval do
        scope :unread, -> (user) { unread_without_order(user).order(created_at: :desc) }

        scope :unread_without_order, -> (user) {
          where.not(
            id: read(user).select(:note_id),
            user_id: user.id
          )
        }

        scope :read, -> (user) {
          joins(:read_notes_users).
            where(read_notes_users: { user_id: user.id, read: true }).
            order(created_at: :desc)
        }

        scope :unread_indicators_with_count, -> (talents_job_ids, user) {
          where(notable_id: talents_job_ids).
          visible_to(user).
          unread_without_order(user).
          group(:notable_id).
          count
        }

        scope :unread_announcements_indicators_with_count, -> (jobs_ids, user) {
          where(notable_id: jobs_ids).
          announcements_visibility_without_order(user).
          unread_without_order(user).
          group(:notable_id).
          distinct.
          count
        }

        scope :visible_to, ->(user) {
          if user.hiring_org_user?
            where(visibility: Note::HO_VISIBILITY)
          elsif user.internal_user?
            where(visibility: Note::CROWDSTAFFING_VISIBILITY)
          elsif user.agency_user?
            where(visibility: Note::TS_VISIBILITY)
          end
        }

        scope :announcements, -> { where(announcement: true) }

        scope :only_parents, -> { where(parent_id: nil) }

        scope :announcements_visibility, -> (user) {
          announcements_visibility_without_order(user).order(created_at: :desc)
        }

        scope :announcements_visibility_without_order, -> (user) {
          visible_to(user).only_parents.announcements
        }

        scope :talents_jobs, -> { where(notable_type: "TalentsJob") }
      end
    end
  end
end
