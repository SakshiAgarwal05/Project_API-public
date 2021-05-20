require 'csmm/smart_distribution'

module Concerns::RecruitersScores
  extend ActiveSupport::Concern

  module ClassMethods
    def csmm_recruiters_and_scores(job, current_user)
      return none unless SdScore.table_exists?
      Rails.logger.info "*"*100

      User.
        verified.
        agency_members.
        visible_to(current_user).
        where.not(id: job.affiliates.invited_or_saved.select(:user_id).distinct).
        joins(
          "left outer join shared.sd_scores on shared.sd_scores.recruiter_id = users.id and
          shared.sd_scores.job_id = '#{job.id}'"
        )
    end
  end
end
