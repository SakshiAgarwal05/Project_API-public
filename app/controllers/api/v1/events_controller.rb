# Controller to manage jobs[../Job.html] in talent namespace.
# Talent van accept and reject the job[../Job.html] offers.
class Api::V1:: EventsController < ApplicationController
  # show an event
  # ====URL
  #  /events/ID?invitation_token=TOKEN [GET]
  def show
    if params[:invitation_token].present?
      @attendee = EventAttendee.find_by(invitation_token: params[:invitation_token])
      if @attendee
        if @attendee.event_id.eql?(params[:id])
          @event = Event.find(params[:id])
        else
          send_403!
        end
      else
        render json: { error: 'Invitation token has expired.' }, status: :unauthorized
      end
    else
      send_403!
    end
  end

  # response of attendee
  # ====URL
  #   events/:ID/attendee_response?invitation_token=TOKEN [POST]
  #   status
  #   note
  #   confirmed_slots
  def attendee_response
    if params[:invitation_token].present?
      @attendee = EventAttendee.find_by(invitation_token: params[:invitation_token])
      if @attendee
        if @attendee.event_id.eql?(params[:id])
          if @attendee.update_attributes(
            status: params[:status],
            note: params[:note],
            confirmed_slots: params[:confirmed_slots]
          )
            @event = Event.find(params[:id])
            notification_decision(@attendee, params, @event)
            render 'show'
          else
            render_errors @attendee
          end
        else
          send_403!
        end
      else
        render json: { error: 'Invitation token has expired.' }, status: :unauthorized
      end
    else
      send_403!
    end
  end

  # download ics file of an event
  # ======URL
  #   events/:ID/download_ics?invitation_token=TOKEN [GET]
  def download_ics
    if params[:invitation_token].present?
      @event = Event.find(params[:id])
      if @event
        respond_to do |format|
          format.ics do
            cal = @event.ics_calendar
            cal.publish
            render plain: cal.to_ical
          end
        end
      else
        send_403!
      end
    else
      send_403!
    end
  end

  private

  def notification_decision(attendee, params, event)
    if (params[:confirmed_slots].present? || event.time_slots.any?) && event.start_date_time.blank?
      if attendee.is_organizer.is_false?
        if attendee.status.eql?('Yes')
          event.inform_organizer_confirmed_slots(attendee)
        elsif params[:event][:notify_attendee].is_true? && ['No', 'Maybe'].include?(attendee.status)
          event.inform_organizer_and_host(attendee)
        end
      end
      SystemNotifications.perform_later(
        event,
        'multi_slot_response',
        current_user,
        get_user_agent,
        attendee
      )
    elsif ['Yes', 'No', 'Maybe'].include?(attendee.status)
      if attendee.status.eql?('Yes') ||
        (params[:event][:notify_attendee].is_true? && ['No', 'Maybe'].include?(attendee.status))
        event.inform_organizer_and_host(attendee)
      end

      SystemNotifications.perform_later(
        event,
        'attendee_responded',
        current_user,
        get_user_agent,
        attendee
      )
    end
  end
end
