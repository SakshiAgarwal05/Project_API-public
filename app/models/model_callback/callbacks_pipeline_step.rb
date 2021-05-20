module ModelCallback
  module CallbacksPipelineStep
    def self.included(receiver)
      receiver.class_eval do
        before_destroy :check_candidates, prepend: true
        after_save :init_metrics_stage, unless: :skip_metrics_update
      end
    end


    ########################
    private
    ########################

    # can't delete a step if a candidate has moved through it.
    def check_candidates
      embeddable_obj = recruitment_pipeline.embeddable
      if embeddable_obj.is_a?(Job) &&
          !embeddable_obj.try(:destroy_children) &&
          embeddable_obj.talents_jobs.includes(:completed_transitions)
          .references(:completed_transitions)
          .where(completed_transitions: {stage: stage_label}).any?
        message = I18n.t('pipeline_step.error_messages.cant_delete_pipeline_step')
        recruitment_pipeline.errors.add(:base, message)
        errors.add(:base, message)
        throw(:abort)
      end
      true
    end

    def init_metrics_stage
      embeddable_obj = recruitment_pipeline.embeddable
      if self.changed.include?('id') && embeddable_obj.is_a?(Job)
        time_delay = Rails.cache.read("update_metrics_job_time_delay_#{embeddable_obj.id}") || 0
        Rails.cache.write(
          "update_metrics_job_time_delay_#{embeddable_obj.id}",
          20 + time_delay,
          expires_in: 5.minutes
        )
        UpdateMetricsJob.set(wait: (10 + time_delay).seconds).perform_later(embeddable_obj.id)
      end
    end

  end
end
