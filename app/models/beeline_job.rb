# class for Beeline jobs inherited from Job
module BeelineJob

  def update_stage_for_beeline
    return if skip_callback == :update_stage_for_beeline
    beeline_status = job_providers.order('created_at desc').first.data['status'] rescue nil
    return if !beeline_status ||
      !beeline? ||
      stage == beeline_status


    if (changed & ['sync_status_from_job_provider', 'stage']).present? &&
      sync_status_from_job_provider

      beeline_update_status(beeline_status)
    elsif beeline_status != 'Open' && stage == 'Draft'
      beeline_update_status(beeline_status)
      self.published_at = nil
      self.enable = false
      self.published_by = nil
    elsif beeline_status == 'Open' && stage != 'Open'
      self.stage = 'Draft'
    end
    self.skip_callback = :update_stage_for_beeline
    save!
    notify_for_beeline
  end

  def notify_for_beeline
    return unless beeline?
    beeline_notification_decision(changed, changes, false)
  end

  def provider_cancel_job
    self.stage = 'Closed'
    self.reason_to_close_job = 'Cancelled by Beeline'
    self.stage_transitions[Time.now] = { stage: stage, reason: reason_to_close_job }
  end

  def provide_filled_job
    self.stage = 'Closed'
    self.reason_to_close_job = 'Filled by request of client'
    self.stage_transitions[Time.now] = { stage: stage, reason: reason_to_close_job }
  end

  def provider_put_on_hold
    self.is_onhold = true
    self.on_hold_at = Time.now
    self.reason_to_onhold_job = "Job on hold set by Beeline"
    self.stage = 'On Hold'
  end

  def provider_unhold
    self.is_onhold = false
    self.reason_to_unhold_job = "Job resumed set by Beeline"
  end

  def beeline_init_attributes(job_params)
    self.assign_attributes(job_params)
    self.category ||=
      Rails.cache.fetch("category_IT", expires_in: 1.month) do
        Category.where(name: 'Information Technology').first
      end

    self.industry ||=
      Rails.cache.fetch("industry_internet", expires_in: 1.month) do
        Industry.where(name: "Internet").first
      end
    self.start_date = [self.start_date, (self.published_at || Date.today)+3.day].max
    if sync_status_from_job_provider
      beeline_update_status(job_params[:stage])
    else
      self.stage = 'Draft'
    end
  end

  def beeline_update_status(stage)
    # return if stage.eql?('Pending')
    self.published_at ||= Time.now
    self.enable = true
    self.published_by = User.beeline
    case stage
    when 'Open'
      self.stage = 'Open'
      self.provider_unhold if is_onhold
    when 'Cancelled'
      provider_cancel_job
    when 'Filled'
      provide_filled_job
    when 'On Hold'
      provider_put_on_hold
    end
  end

  def beeline_notification_decision(changed, changes, new_job)
    return if changed.blank?
    if changed.include? 'stage'
      case stage
      when 'Closed', 'Filled'
        beeline_close_job
      when 'Open'
        %w(Closed Filled).include?(changes["stage"][0]) ? beeline_reopened_job : beeline_publish_job
      end
    elsif changed.include?('is_onhold')
      is_onhold? ? beeline_hold_job : beeline_resume_job
    elsif new_job
      beeline_create_job
    else
      beeline_update_job
    end
  end

  def beeline_notify_admins
    admins.each { |user| JobsMailer.notify_beeline_job_published(user, self).deliver_now }
  end

  def beeline_publish_job
    create_notificaton(
      User.beeline,
      {},
      'job_published',
      'Job published by Beeline',
      "Job from Beeline has been Published",
      "<a href='/#/recruiting-job/#{id}'>#{title}</a> at <a href='/#/clients/#{client.id}'>#{client.company_name}</a> has been published",
      stackholders,
      self
      )
  end

  def beeline_create_job
    create_notificaton(
      User.beeline,
      {},
      'job_created',
      'Job Created by Beeline',
      "Job from Beeline has been created",
      "Job <a href='/#/recruiting-job/#{id}'>#{title}</a> at <a href='/#/clients/#{client.id}'>#{client.company_name}</a> has been created",
      stackholders,
      self
    )
  end

  def beeline_update_job
    create_notificaton(
      User.beeline,
      {},
      'job_updated',
      'Job Updated by Beeline',
      "Job from Beeline has been updated",
      "Job <a href='/#/recruiting-job/#{id}'>#{title}</a> at <a href='/#/clients/#{client.id}'>#{client.company_name}</a> has been updated",
      stackholders,
      self
    )
    stackholders.each { |user| JobsMailer.notify_beeline_job_updated(user, self).deliver_now }
  end

  def stackholders
    published? ? (admins + picked_by).flatten.compact.uniq : admins
  end

  def admins
    client.shared_users
  end

  def beeline_close_job
    SystemNotifications.perform_later(self, 'job_close', User.beeline, nil)
    beeline_notifiation_action(
      admins,
      'job_close',
      'Job Closed',
      "Job <a href='/#/recruiting-job/#{id}'>#{title}</a> is closed because #{reason_to_close_job}")

    admins.each { |user| JobsMailer.notify_job_close(user, self).deliver_now }
  end

  def beeline_hold_job
    SystemNotifications.perform_later(self, 'job_onhold', User.beeline, nil)
    beeline_notifiation_action(
      admins,
      'job_onhold',
      'Job On-Hold',
      "Job <a href='/#/recruiting-job/#{id}'>#{title}</a> is put on hold because #{reason_to_onhold_job}")
  end

  def beeline_resume_job
    SystemNotifications.perform_later(self, 'job_unhold', User.beeline, nil)
    beeline_notifiation_action(
      admins,
      'job_unhold',
      'Job Resumed',
      "Job <a href='/#/recruiting-job/#{id}'>#{title}</a> is now accepting applicants as has been resumed")
  end

  def beeline_reopened_job
    SystemNotifications.perform_later(self, 'job_reopen', User.beeline, nil)
    beeline_notifiation_action(
      admins,
      'job_reopened',
      'Job Reopened',
      "Job <a href='/#/recruiting-job/#{id}'>#{title}</a> is reopened and enabled now because #{reason_to_unhold_job}")

  end

  def beeline_create_announcement(billing)
    return unless billing
    note = "This job is having following billing terms. <br />"
    billing.each{ |key, value|
      min = value['min-amount']
      note += "#{key}: #{min} - #{value['max-amount']} #{billing['currency']} #{billing['unit']}<br />" if min
    }
    return if notes.where(announcement: true, note: note).any?
    notes.create!(announcement: true, visibility: 'EVERYONE', note: note, user: account_manager)
  end

  def beeline_notifiation_action(users, key, label, message)
    options = {
      show_on_timeline: false,
      user_agent: nil,
      object: self,
      key: key,
      label: label,
      message: message,
      from: User.beeline,
      read: true,
      viewed_or_emailed: true,
      visibility: nil,
      created_at: Time.now,
      updated_at: Time.now
    }

    batch = users.collect{ |user| options.merge({receiver: user}) }

    unless batch.blank?
      insert_many = Notification.create(batch)
      insert_many.each{|record| record.send(:pusher_notification) if record.persisted?}
    end
  end

end
