module ModelCallback
  module CallbacksRecruitmentPipeline
    def self.included(receiver)
      receiver.class_eval do
        before_validation :add_fixed_steps, on: :create
        before_validation :reorder
        before_destroy :if_deletable?
        after_save :save_next_step
      end
    end

    ########################
    private
    ########################

    def save_next_step
      return unless self.embeddable.is_a?(Job)
      self.embeddable.talents_jobs.each do |t|
        t.next_stage = t.stages[t.stage]
        t.save
      end
    end

    # add fixed steps to before and after variable steps
    def add_fixed_steps
      skip_metrics_update = !embeddable.is_a?(Job) || embeddable.talents_jobs.count.zero?
      pipeline_steps.each{|step| step.skip_metrics_update = skip_metrics_update}
      return if copy
      PipelineStep::FIXED_STARTING_STEPS.each do |step|
        if pipeline_steps.where(stage_label: step[:stage_label]).blank?
          s = PipelineStep.new(step)
          s.fixed = true
          s.stage_type = s.stage_label
          s.skip_metrics_update = skip_metrics_update
          self.pipeline_steps << s
        end
      end

      steps = (embeddable.is_a?(HiringOrganization) && embeddable.beeline?) ?
        PipelineStep::BEELINE_FIXED_END_STEPS : PipelineStep::FIXED_END_STEPS

      steps.each do |step|
        if pipeline_steps.where(stage_label: step[:stage_label]).blank?
          s = PipelineStep.new(step)
          s.fixed = true
          s.stage_type = s.stage_label
          s.skip_metrics_update = skip_metrics_update
          self.pipeline_steps << s
        end
      end

    end

    # can not delete a recruitment pipeline if its embedded with a job.
    def if_deletable?
      embeddable_obj = embeddable
      if (embeddable_obj.is_a?(Job) && !embeddable_obj.destroy_children) ||
         (embeddable_obj.is_a?(HiringOrganization) &&
          embeddable_obj.recruitment_pipelines.count == 1)
        errors.add(:base,
                   I18n.t('recruitment_pipeline.error_messages.cannot_delete'))
        return false
      end
      true
    end

    # reorder variable steps
    def reorder
      changed_fields = pipeline_steps.collect(&:changed).flatten.uniq
      return true if changed_fields == ['count'] || changed_fields.empty?
      o = 2.0
      self.pipeline_steps.select{|x| !x.fixed && !x.marked_for_destruction?}
        .sort{|x,y| x.stage_order <=> y.stage_order}.each do |step|
        step.stage_order = (o += 0.1)
      end
    end
  end
end
