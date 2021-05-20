module Concerns::CommonCsmmCallbacks
  extend ActiveSupport::Concern

  def self.included(receiver)
    receiver.class_eval do
      after_destroy :destroy_csmm_dependency
    end
  end

  def destroy_csmm_dependency
    CsmmTaskHandlerJob.set(wait: 1.minutes).perform_later(
      'destroy_dependent_objects',
      { object_type: self.class.to_s, object_id: id }
    )
  end
end
