module ModelCallback
  module CallbacksOnboard
    def self.included(receiver)
      receiver.class_eval do
        before_save :complete_action
        after_save :update_completed_transitions
      end
    end


    ########################
    private
    ########################

    def complete_action
      return unless changed.include?("file")
      self.action_completed = !file.blank?
      self.status = "pending"
    end

    def update_completed_transitions
      completed_transition = talents_job.
        completed_transitions.where(stage: "On-boarding").
        order("created_at asc").
        last

      return unless completed_transition
      if completed_transition.tag != "in-progress" &&
        talents_job.onboards.where(action_completed: true).any?

        completed_transition.update_column(:tag, "in-progress")
      end

      return unless (completed_transition.tag != "completed" &&
        talents_job.onboards.count == talents_job.onboards.approved.count)

      completed_transition.update_column(:tag, "completed")
    end

  end
end
