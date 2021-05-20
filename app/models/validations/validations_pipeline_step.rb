module Validations
  module ValidationsPipelineStep
    def self.included(receiver)
      receiver.class_eval do
        validates :stage_type, :stage_label, :stage_order, presence: true
        validates :stage_label, uniqueness: { scope: :recruitment_pipeline },
          if: proc { |obj| obj.recruitment_pipeline_id.present? }
        validates :stage_type, inclusion: {in: PipelineStep::STAGE_TYPES}
        validate  :is_pipeline_step_editable, on: :update
      end
    end


    ########################
    private
    ########################
    def is_pipeline_step_editable
      embeddable_obj = recruitment_pipeline.embeddable
      rp = recruitment_pipeline
      return if !changed.include?('stage_order')
      return unless embeddable_obj.is_a?(Job)
      talents_jobs = embeddable_obj.talents_jobs
      return if talents_jobs.empty?

      juggled = rp.pipeline_steps.where(stage_order: stage_order_was).last
      juggled_stage = juggled.stage_label if juggled
      return true unless juggled
      can_juggled = juggled.new_record? || talents_jobs.reached_at(juggled_stage).count.zero?
      return true if can_juggled
      message = I18n.t('pipeline_step.error_messages.cant_edit_pipeline_step')
      recruitment_pipeline.errors.add(:base, message)
      return false
    end
  end
end
