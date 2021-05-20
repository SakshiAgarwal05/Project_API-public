require 'jwt'

class Api::V1:: SharelinksController < ApplicationController
  # /sharelinks/:id [GET]
  def show
    @share_link = ShareLink.where(token: params[:id]).first

    if @share_link&.shared&.is_a?(Job)
      job = Job.find(@share_link.shared_id)
      if job.enable_shareable_link? && Job::STAGES_FOR_APPLICATION.include?(job.stage)

        clicks, referrer = get_yourls_logs(@share_link.yourl_keyword)
        shareable = @share_link.shareables.find_or_create_by(
          job_id: @share_link.shared_id,
          user_id: @share_link.created_by_id,
          referrer: referrer&.humanize,
          yourl_keyword: @share_link.yourl_keyword
        )

        impressionist(shareable)
        ShareableJob.perform_later(
          @share_link.id, clicks, referrer, shareable.id, request.remote_ip
        )

        payload = { shared_token: @share_link.token, timestamp: Time.now.to_i }
        token = JWT.encode(payload, Rails.application.secrets.secret_key_base, 'HS256')

        url = "#{JOBS_FE_HOST}/jobs/#{@share_link.shared_id}"

        redirect_to "#{url}?token=#{token}&share_link_id=#{@share_link.id}&referrer=#{referrer}"
      else
        redirect_to "#{JOBS_FE_HOST}/404"
      end
    else
      redirect_to "#{JOBS_FE_HOST}/404"
    end
  end

  # /sharelinks/check_signed_url [POST]
  def check_signed_url
    decode = begin
              JWT.decode(params[:token], Rails.application.secrets.secret_key_base, 'HS256')
            rescue JWT::DecodeError
              {}
            end

    share_link = ShareLink.where(token: decode[0]['shared_token']).first
    return send_403! if share_link.blank?

    job = Job.find(share_link.shared_id)

    return send_403! if job.blank? || job.enable_shareable_link.is_false? || Job::STAGES_FOR_APPLICATION.exclude?(job.stage)

    user = share_link.created_by
    render json: {
      share_link: {
        created_by_id: share_link.created_by_id,
        first_name: user.first_name,
        last_name: user.last_name,
        avatar: user.avatar,
        email: user.email,
      },
    }, status: :ok
  end

  # Shareable source pickers
  # ====URL
  # sharelinks/source_pickers [GET]
  def source_pickers
    shareables = Shareable.pluck('distinct referrer')
    render json: shareables, status: :ok
  end

  private

  def get_yourls_logs(keyword)
    referrer = 'Direct'
    clicks = YourlsUrl.find_by(keyword: @share_link.yourl_keyword)&.clicks

    log = YourlsLog.
      where(shorturl: @share_link.yourl_keyword).
      order(click_time: :desc).
      first

    if log.present?
      host = URI.parse(log.referrer)&.hostname
      if host.present?
        referrer = host.eql?('t.co') ? 'Twitter' : PublicSuffix.parse(host).sld
      end
      referrer
    end

    [clicks, referrer]
  end
end
