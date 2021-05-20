module Scopes
  module ScopesEvent
    def self.included(receiver)
      receiver.class_eval do
        scope :future, -> { where('events.start_date_time > ?', Time.now.utc) }
        scope :past, -> { where('events.end_date_time < ?', Time.now.utc) }
        scope :upcoming_events, -> { where("events.start_date_time > now()") }
        scope :not_declined, -> { where(declined: false) }
        scope :declined, -> { where(declined: true) }
        scope :pending, -> { where("events.start_date_time is NULL AND confirmed = ?", false) }
        scope :confirmed, -> { where(confirmed: true) }

        scope :by_categories, ->(categories, current_user_id) {
          records = all
          values = categories.values
          return records if values.count(true) == 7 || values.count(false) == 7

          records = records.joins(:event_attendees)
          final_events = []

          if categories[:declined]
            declined_events = records.where("
              declined = :t_var OR
              (declined = :f_var AND
                event_attendees.user_id = :user_id AND
                event_attendees.status = 'No' AND
                (events.start_date_time is NULL OR events.start_date_time > :time)) OR
              (declined = :f_var AND
                event_attendees.user_id = :user_id AND
                event_attendees.status IN ('No', 'pending', 'Maybe') AND
                ((events.start_date_time <= :time AND events.end_date_time > :time) OR events.end_date_time <= :time)
              )", { user_id: current_user_id, t_var: true, f_var: false, time: Time.now.utc }
            )

            final_events.push(declined_events)
          end

          if categories[:expired]
            unless records.to_sql.match(/left outer join\W*time_slots/i)
              records = records.left_outer_joins(:time_slots)
            end

            non_declined_pending = records.not_declined.where("
              events.start_date_time is NULL OR events.request = ?", true
            )

            expired = non_declined_pending.where(
                id: non_declined_pending.group(:id).having(
                  "sum(case when time_slots.start_date_time < now() then 0 else 1 end) = 0"
                ).pluck(:id)
              )

            final_events.push(expired)
          end

          if categories[:requested]
            unless records.to_sql.match(/left outer join\W*time_slots/i)
              records = records.left_outer_joins(:time_slots)
            end

            # future requested events
            requested_events = records.not_declined.pending.where.not(
              'time_slots.start_date_time < ?',
              Time.now.utc
            )

            if requested_events.where(event_attendees: { user_id: current_user_id }).any?
              requested_events = requested_events.where(
                "event_attendees.user_id = ? AND event_attendees.status in ('pending', 'Yes')",
                current_user_id
              )
            end

            requested_events = records.where(
              "events.id in (?) OR (
                events.start_date_time IS NOT NULL AND declined = ? AND event_attendees.user_id = ? AND
                event_attendees.status = 'pending' AND events.start_date_time > ?)",
              requested_events.distinct.pluck(:id), false, current_user_id, Time.now.utc
            )

            final_events.push(requested_events)
          end

          if categories[:scheduled]
            scheduled_events = records.not_declined.confirmed.future

            if scheduled_events.where(event_attendees: { user_id: current_user_id }).any?
              scheduled_events = scheduled_events.
                where(event_attendees: { user_id: current_user_id, status: 'Yes' })
            end

            final_events.push(scheduled_events)
          end

          if categories[:in_progress]
            in_progress_events = records.not_declined.confirmed.
              where('events.start_date_time <= :time AND events.end_date_time > :time', { time: Time.now.utc })

            if in_progress_events.where(event_attendees: { user_id: current_user_id }).any?
              in_progress_events = in_progress_events.
                where(event_attendees: { user_id: current_user_id, status: 'Yes' })
            end

            in_progress_events = records.where(
              "events.id in (?) OR
              (declined = ? AND
              confirmed = ? AND
              events.start_date_time <= ? AND
              events.end_date_time > ?)",
              in_progress_events.distinct.pluck(:id), false, true, Time.now.utc, Time.now.utc
            )

            final_events.push(in_progress_events)
          end

          if categories[:completed]
            completed_events = records.not_declined.confirmed.where('events.end_date_time <= ?', Time.now.utc)

            if completed_events.where(event_attendees: { user_id: current_user_id }).any?
              completed_events = completed_events.
                where(event_attendees: { user_id: current_user_id, status: 'Yes' })
            end

            completed_events = records.where(
              "events.id in (?) OR (declined = ? AND confirmed = ? AND events.end_date_time <= ?)",
              completed_events.distinct.pluck(:id), false, true, Time.now.utc
            )

            final_events.push(completed_events)
          end

          if categories[:maybe]
            final_events.push(
              records.not_declined.confirmed.future.where(
                event_attendees: { user_id: current_user_id, status: 'Maybe' }
              )
            )
          end

          if final_events.count.eql? 1
            final_events[0].distinct
          else
            final_events = final_events.map{ |x| x.select(:id) }.map(&:to_sql).join(" UNION ")
            records.where("events.id in (#{final_events})").distinct
          end
        }

        scope :order_by_recently_created, ->(order_field, order) {
          get_order(Arel.sql("events.#{order_field || 'created_at'}"), order)
        }

        scope :confirmed_not_completed, -> {
          where("(events.end_date_time > :x) OR (events.start_date_time > :x)", { x: Time.now })
        }

        scope :user_events, -> (user_id) {
          user = User.find(user_id)
          return none if user.blank?

          where(id: user.event_attendees.select(:event_id)).
            or(where(related_to_type: 'User', related_to_id: user.id))
        }

        scope :talent_events, ->(talent_id) {
          talent = Talent.find(talent_id) || Profile.find(talent_id)&.talent
          return none if talent.blank?

          where(id: talent.event_attendees.select(:event_id)).
            or(where(related_to_type: 'Talent', related_to_id: talent.id))
        }

        scope :client_events, ->(client_id) {
          where(related_to_type: 'Client', related_to_id: client_id)
        }

        scope :job_events, ->(job_id) {
          where(job_id: job_id).or(where(related_to_type: 'Job', related_to_id: job_id))
        }

        scope :get_tj_job_events, ->(jobs, closed_jobs, user) {
          events = visible_to(user).where(event_type: Event::EVENT_TYPES, job_id: jobs)

          events = events.where.not(id: user.event_attendees.pluck(:event_id)).or(
            events.where(id: user.event_attendees.unremoved.pluck(:event_id))
          )

          events = events.where(active: true) unless closed_jobs

          events
        }

        scope :filter_date_range, ->(start_date, end_date, sort_order = false) {
          if end_date.nil?
            events = where(
              "(events.start_date_time is NULL and time_slots.start_date_time >= :time) OR
              events.start_date_time >= :time", { time: start_date }
            )
          else
            events = where(
              "(events.start_date_time is NULL and time_slots.start_date_time BETWEEN ? and ?) OR
              events.start_date_time BETWEEN ? and ?", start_date, end_date, start_date, end_date
            )
          end

          unless events.to_sql.match(/left outer join\W*time_slots/i)
            events = events.left_outer_joins(:time_slots)
          end

          if sort_order.is_true? && end_date.nil?
            events = events.group('events.id').select('events.*, (case when events.start_date_time is NULL then max(time_slots.start_date_time) ELSE events.start_date_time end)').order("case when events.start_date_time is NULL then max(time_slots.start_date_time) ELSE events.start_date_time end asc")
          end

          events
        }

        scope :filter_start_range, ->(start_date) {
          events = where(
            "(events.start_date_time is NULL and time_slots.start_date_time >= ?) OR
            events.start_date_time >= ?", start_date, start_date
          )
          unless events.to_sql.match(/left outer join\W*time_slots/i)
            events = events.left_outer_joins(:time_slots)
          end
          events
        }

        scope :adminapp_events, -> (user) {
          return unless user.is_a?(User)
          return none if user.hiring_org_user?
          where(
            Arel.sql("(related_to_type = 'TalentsJob' AND #{Event.get_talents_jobs_query(user)})")
          )
        }

        scope :own_events, -> (user, options = {}) {
          return unless user.is_a?(User)
          if options[:type].eql?('public')
            event_ids = EventAttendee.
              where(user_id: User.visible_to(user).where.not(id: user.id).
                select(:id)).select(:event_id)

            where(id: event_ids).or(where(id: user.event_attendees.unremoved.select(:event_id)))
          else
            where(id: user.event_attendees.unremoved.select(:event_id))
          end
        }

        # Note: not sure if events/my has been used by FE or not.
        scope :my_events, ->(user) {
          return unless user.is_a?(User)
          if user.agency_user?
            return none unless user.all_permissions.dig('actions events', 'view org events')

            return adminapp_events(user).where(tj_user_id: user.id).or(own_events(user))
          elsif user.internal_user?
            if user.all_permissions.dig('actions events', 'view clients events')
              return adminapp_events(user).where(job_id: Job.saved_by_me(user).select(:id)).
                  or(job_events(Job.saved_by_me(user).select(:id))).
                  or(own_events(user))
            elsif user.all_permissions.dig('actions events', 'view org events')
              return where(nil)
            end
          elsif user.hiring_org_user?
            return none unless user.all_permissions.dig('actions events', 'view jobs events')
            return own_events(user)
          end

          none
        }

        scope :visible_to, ->(user) {
          return none unless user.is_a?(User)

          if user.agency_user?
            return none unless user.all_permissions.dig('actions events', 'view org events')
            return adminapp_events(user).or(own_events(user, { type: 'public' }))
          elsif user.internal_user?
            if user.all_permissions.dig('actions events', 'view clients events')
              return adminapp_events(user).
                  or(own_events(user)).
                  or(client_events(user.assignables.select(:client_id))).
                  or(job_events(Job.where(client_id: user.assignables.select(:client_id))))

            elsif user.all_permissions.dig('actions events', 'view org events')
              return self
            end
          elsif user.hiring_org_user?
            return where(job_id: user.hiring_organization.jobs.select(:id))
          end
        }

        scope :date_range, ->(start_date, end_date) {
          events = where(
            "(events.start_date_time is NULL and time_slots.start_date_time BETWEEN ? and ?) OR
            events.start_date_time BETWEEN ? and ?", start_date, end_date, start_date, end_date)
          unless events.to_sql.match(/left outer join\W*time_slots/i)
            events = events.left_outer_joins(:time_slots)
          end
          events
        }

        scope :for_resources, -> (type, resource_ids) {
          case type
          when 'Job'
            where(related_to_type: 'Job', related_to_id: resource_ids)
          when 'TalentsJob'
            where(related_to_type: 'TalentsJob', related_to_id: resource_ids)
          else
            none
          end
        }
      end
    end
  end
end
