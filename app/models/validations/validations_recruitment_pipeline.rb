module Validations
  module ValidationsRecruitmentPipeline
    def self.included(receiver)
      receiver.class_eval do
        validates :name, :description, presence: true
        validates :name, uniqueness: { scope: :embeddable }
        validate :five_steps_limit
      end
    end

    ########################
    private
    ########################

    # can't add more than 5 custom steps
    def five_steps_limit
      return self.pipeline_steps.select{|x| !x.fixed && !x.marked_for_destruction?}.count <= 5
      self.errors.add(:base, "You can't add more than 5 steps")
    end

  end
end
