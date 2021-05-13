class EmailsController < ApplicationController
  skip_load_and_authorize_resource only: [:view]
  http_basic_authenticate_with  name: ENV['WEBHOOK_USER'],
                                password: ENV['WEBHOOK_PASSWORD'],
                                only: [:view]

  def view
    list_of_emails = params["_json"]
    list_of_emails.each do |email|
      update_messages(email)
      if email['mail_for']
        if ['open', 'click'].include?(email['event'])
          if email['mail_for'] == 'job_invite'
            user = User.find(email['user_id'])
            job = Job.find(email['job_id'])
            affiliate_record = Affiliate.find_by(
              job_id: job.id,
              user_id: user.id,
              type: email['type']
            )
            if affiliate_record
              affiliate_record.update_column(:email_status, email['event'])
            elsif email['type'] == 'RecruitersJob'
              user.recruiters_jobs.create(
                job_id: job.id,
                status: 'active',
                email_status: email['event'],
                agency_id: user.agency_id
              )
            end
          elsif email['talents_job_id']
            talent_job = TalentsJob.find(email['talents_job_id'])
            if talent_job
              case email['mail_for']
              when 'invite'
                talent_job.read_invitation(email['rtr_id'])
              when 'offer'
                talent_job.read_offer
              when 'rtr'
                rtr = talent_job.all_rtr.select{|r| r.id == email['rtr_id']}.first
                rtr.update_attributes(tag: 'opened') if rtr
              end
            end
          elsif email['user_id'] && email['mail_for'] != 'job_invite'
            user = User.find(email['user_id'])
            timestamp = email['timestamp']
            date = DateTime.strptime(timestamp.to_s,'%s') if timestamp
            if email["event"].eql?("click") && user && user.viewed_invite.is_false?
              user.viewed_invitation(date)
              user.update(viewed_invite: true)
            elsif user && user.confirmation_status.is_false?
              case email['mail_for']
              when 'read_invite'
                user.read_invitation(date)
                user.update(confirmation_status: true)
              end
            end
          end
        end
      end
    end
    head :ok
  end

  def reply
    email = MailboxMailer.receive(params)
    head :ok
  end

  def update_messages(email)
    message = Message.find(email["message_id"])
    if message
      receiver = message.receivers.find_by_email(email["email"])
      if receiver
        receiver.sendgrid_status = email["event"]
        receiver.open_via = 'Third Party' if ['open', 'click'].include?(email['event'])
        receiver.save(validate: false)
        if ['dropped', 'deferred', 'bounce'].include?(receiver.sendgrid_status.downcase)
          receiver.create_fail_message
          if Rails.env.production?
            ActionMailer::Base.mail(
              from: "'Crowdstaffing'<noreply@crowdstaffing.com>",
              to: 'ohoh@crowdstaffing.com',
              subject: 'Email Delivery Failed',
              body: "#{receiver.email} Failed to deliver email because it was #{receiver.sendgrid_status}").deliver_later
          end
        end
      end
    end
  end

  private

  def contact_params
    params.require(:contact_us).permit(:first_name, :last_name, :phone_no, :subject, :message, :email)
  end
end
