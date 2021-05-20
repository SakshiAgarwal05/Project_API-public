module Concerns::JobRecruiters
  extend ActiveSupport::Concern

  def invited_recruiters
    User.invited_distributed_restricted_jobs(self)
  end

  def saved_and_invited_recruiters_query
    t =
      if user.restrict_access
        %w(Invitation AccessibleJob RecruitersJob)
      else
        %w(Invitation RecruitersJob)
      end

    User.joins(:affiliates).
      where(affiliates: { type: t, job: self }).
      distinct
  end

  def current_invited_recruiters
    invited_recruiters
  end
end
