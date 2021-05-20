module Admin
  module SharelinksHelper
    def sharelinks_clicks(sharelinks)
      {
        total_shared_links: sharelinks.count,
        unique_shared_links: sharelinks.pluck(:shared_id).uniq.count,
      }
    end

    def yourls_clicks(sharelinks)
      prev_clicks = sharelinks.
        where(created_at: PREV_FROM_TIME..PREV_TO_TIME).pluck(:clicks).compact.sum

      current_clicks = sharelinks.
        where(created_at: FROM_TIME..TO_TIME).pluck(:clicks).compact.sum

      unless prev_clicks.zero?
        click_delta = begin
                        ((current_clicks - prev_clicks) * 100) / prev_clicks
                      rescue
                        0
                      end
      end

      {
        total_clicks: sharelinks.pluck(:clicks).compact.sum,
        click_delta: prev_clicks.zero? ? 'N/A' : click_delta.to_f,
      }
    end

    def sharelinks_views(shareables)
      prev_views = shareables.
        where(created_at: PREV_FROM_TIME..PREV_TO_TIME).pluck(:visits).compact.sum

      current_views = shareables.
        where(created_at: FROM_TIME..TO_TIME).pluck(:visits).compact.sum

      unless prev_views.zero?
        view_delta = begin
                       ((current_views - prev_views) * 100) / prev_views
                     rescue
                       0
                     end
      end

      {
        total_views: shareables.pluck(:visits).compact.sum,
        view_delta: prev_views.zero? ? 'N/A' : view_delta.to_f,
      }
    end

    def sharelinks_applicants(shareables)
      new_applicants = shareables.shared_talents.where(existing_talent: false)

      {
        applicants: shareables.shared_talents.pluck('Distinct(talent_id)').count,
        new_applicants: new_applicants.pluck('Distinct(talent_id)').count,
      }
    end

    def sharelinks_agencies(sharelinks)
      results = []

      clicks = sharelinks.
        group(:created_by_id).
        sum(:clicks).sort_by { |_k, v| v }.
        reverse[0..3].to_h

      clicks.each do |user_id, visits_count|
        user = User.find(user_id)
        next if user.blank?
        results << {
          first_name: user.first_name,
          last_name: user.last_name,
          agency: user&.agency&.company_name,
          clicks: clicks[user.id],
          visits: sharelinks.where(created_by_id: user_id).sum(:visits),
          avatar: user.avatar,
          image_resized: user.image_resized,
        }
      end

      results
    end

    def publishing_options_power(job)
      current_user.can?(:update, job) &&
        (current_user.internal_user? || current_user.hiring_org_user?) &&
        job.if_my_job(current_user) &&
        ['Draft', 'Scheduled', 'Closed'].exclude?(job.stage)
    end
  end
end
