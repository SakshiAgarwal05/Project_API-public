module Scopes
  module ScopesReceiver
    def self.included(receiver)
      receiver.class_eval do
        scope :receiver_users, -> { where.not(user_id: nil) }

        scope :bcc_receivers, -> { where(receiver_type: 'bcc') }

        scope :cc_receivers, -> { where(receiver_type: 'cc') }

        scope :to_receivers, -> { where(receiver_type: 'to') }

        scope :recepients, -> { where.not(receiver_type: 'from') }

        scope :from_receiver, -> { where(receiver_type: 'from') }

        scope :is_sendable, -> { where(send_email: true) }

        scope :total_unread_messages, -> { where(open_via: nil).count }

        scope :inbox_messages, -> (user_id) {
          where(
            user_id: user_id,
            receiver_type: ['to', 'cc', 'bcc'],
            delete_after_archived_time: nil
          ).joins(:message).where(messages: { status: [nil, 'sent'] }).distinct
        }

        scope :sent_messages, -> (user_id) {
          where(
            user_id: user_id,
            receiver_type: 'from',
            delete_after_archived_time: nil
          ).joins(:message).where(messages: { status: [nil, 'sent'] }).distinct
        }

        scope :featured_messages, -> (user_id) {
          where(user_id: user_id, delete_after_archived_time: nil, featured: true)
        }

        scope :trash_messages, -> (user_id) {
          where('user_id = ? AND delete_after_archived_time IS NOT null', user_id)
        }

        scope :draft_messages, -> (user_id) {
          where(
            receiver_type: 'from',
            user_id: user_id,
            delete_after_archived_time: nil
          ).joins(:message).where(messages: { status: 'draft' }).distinct
        }

        scope :deleted_draft_messages, -> {
          where('receiver_type = ? AND delete_after_archived_time IS NOT null', 'from')
          .joins(:message).where(messages: { status: 'draft' }).distinct
        }

        scope :bounced_messages, -> (user_id) {
          where(
            receiver_type: 'to',
            user_id: user_id,
            delete_after_archived_time: nil
          ).joins(:message).where(messages: { status: Message::BOUNCED_STATUS }).distinct
        }

        scope :visible_to, -> (user) {
          if user.internal_user?
            where("receivers.email = ? OR
              ((user_id not in (SELECT users.id from users where locked_at is not null) AND user_id is not NULL) OR
              (talent_id not in (SELECT talents.id from talents where locked_at is not null) AND talent_id is not NULL))",
              'mailer-daemon@crowdstaffing.com'
            )
          elsif user.agency_user?
            active_user_receivers = joins(:user).where(users: { locked_at: nil })
            active_talent_receivers = joins(:talent).where(talents: { locked_at: nil })
            agency_id = user.agency_id

            active_user_receivers = active_user_receivers.where(users: { role_group: 1 })
              .or(active_user_receivers.where(users: { role_group: 2, agency_id: agency_id }))

            if user.limited_access?
              ho_ids = Accessible.where(agency_id: agency_id, incumbent: true).select(:hiring_organization_id).distinct

              active_user_receivers =
                if ho_ids.any?
                  active_user_receivers
                    .or(joins(:user).where(users: { role_group: 3, hiring_organization_id: ho_ids, locked_at: nil }))
                else
                  active_user_receivers
                end
            end

            all_ids = active_user_receivers.select(:id).to_sql +
              " UNION " +
              active_talent_receivers.where(talent_id: Profile.my(user).select(:talent_id).distinct).select(:id).to_sql

            where("receivers.id in (#{all_ids}) OR receivers.email = ?", 'mailer-daemon@crowdstaffing.com')

          elsif user.hiring_org_user?
            active_user_receivers = joins(:user).where(users: { locked_at: nil })
            active_talent_receivers = joins(:talent).where(talents: { locked_at: nil })
            ho_id = user.hiring_organization_id

            active_user_receivers = active_user_receivers
              .where(users: { role_group: 1 })
              .or(active_user_receivers.where(users: { role_group: 3, hiring_organization_id: ho_id }))

            agency_ids = Accessible.where(hiring_organization_id: ho_id, incumbent: true).select(:agency_id).distinct

            active_user_receivers =
              if agency_ids.any?
                active_user_receivers.or(joins(:user).where(users: { role_group: 2, agency_id: agency_ids, locked_at: nil }))
              else
                active_user_receivers
              end

            all_ids = active_user_receivers.select(:id).to_sql +
              " UNION " +
              active_talent_receivers.where(talent_id: Profile.my(user).select(:talent_id).distinct).select(:id).to_sql

            where("receivers.id in (#{all_ids}) OR receivers.email = ?", 'mailer-daemon@crowdstaffing.com')
          else
            none
          end
        }
      end
    end
  end
end
