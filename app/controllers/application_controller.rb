class ApplicationController < ActionController::Base
  include ActionController::ImplicitRender
  include Pagy::Backend

  require 'csv'
  respond_to :json, :html, :csv
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  rescue_from JWT::ExpiredSignature, with: :loggedout
  # We need to test following exception.
  rescue_from Net::SMTPAuthenticationError, Net::SMTPServerBusy,
              Net::SMTPSyntaxError, Net::SMTPFatalError,
              Net::SMTPUnknownError, with: :handle_email_exception
  rescue_from Elasticsearch::Transport::Transport::Errors::NotFound, with: :handle_es_index
  before_action :check_valid_subdomains
  before_action :set_headers, except: :unmatchd_routes
  before_action :configure_permitted_parameters, if: :devise_controller?, except: :unmatchd_routes
  before_action :set_current_talent, except: :unmatchd_routes
  before_action :check_for_valid_action, except: :unmatchd_routes
  before_action :add_new_skills, except: :unmatchd_routes
  before_action :add_new_positions, except: :unmatchd_routes
  before_action :add_new_industries, except: :unmatchd_routes
  before_action :add_new_tags, except: :unmatchd_routes
  helper_method :page_json, :page_count, :per_page
  before_action :attach_current_user_to_obj, except: :unmatchd_routes
  before_action :get_user_agent, except: :unmatchd_routes
  before_action :store_logging_fields, except: :unmatchd_routes

  unless Rails.application.config.consider_all_requests_local
    rescue_from ActionController::RoutingError, with: :unmatchd_routes! # MISS(TODO: TEST CASES NOT WRITTEN)
  end

  def store_logging_fields
    RequestStore.store[:request_id] = request.uuid
    RequestStore.store[:user_id] = current_user.try(:id)
    # RequestStore.store[:params] = params.except('controller', 'action', 'format', 'utf8')
  end

  def get_order(default)
    default = 'desc' if default && !['asc', 'desc'].include?(default.downcase)
    params[:order] = (params[:order] && params[:order].downcase == 'asc' ? 'asc' : default)
  end

  def handle_es_index(error)
    x = JSON.parse error.as_json.gsub('[404] ', '')
    return unless x['error']['reason']
    model, id, e = x['error']['reason'].split(/\[|\]/).select { |x| x.present? }
    model = model.camelize.constantize
    obj = model.find(id)
    obj.__elasticsearch__.update_document
  end

  def add_new_skills
    key = nil
    [:job, :agency, :talent, :profile, :team, :user].each do |object_name|
      next if params[object_name].blank?
      key = object_name if params[object_name]
    end
    return if key.nil? || params[key][:skill_ids].blank?
    add_new_data(Skill, params[key], :skill_ids) # MISS(TODO: TEST CASES NOT WRITTEN)
  end

  def add_new_data(class_name, key, attribute)
    existing = class_name.where(id: key[attribute]).pluck(:id)
    new_data = key[attribute] - existing
    if new_data.present?
      new_ids = []
      new_data.each do |d|
        if s = class_name.find_or_create_by(name: d)
          new_ids << s.id
        end
      end
      key[attribute] = existing + new_ids
    end
  end

  def add_new_positions
    key = nil
    [:job, :talent, :profile, :team, :user].each do |p|
      key = p if params[p]
    end
    if params[:controller].eql?('talent/profiles') && params[:action].eql?('update')
      talent_preference = params[:talent][:talent_preference]
      return if talent_preference.nil? || talent_preference[:position_ids].blank?
      add_new_data(Position, talent_preference, :position_ids) # MISS(TODO: TEST CASES NOT WRITTEN)
    end
    return if key.nil? || params[key][:position_ids].blank?
    add_new_data(Position, params[key], :position_ids) # MISS(TODO: TEST CASES NOT WRITTEN)
  end

  def add_new_industries
    key = nil
    [:agency, :talent, :profile, :team, :user].each do |p|
      key = p if params[p]
    end
    return if key.nil? || params[key][:industry_ids].blank?
    add_new_data(Industry, params[key], :industry_ids) # MISS(TODO: TEST CASES NOT WRITTEN)
  end

  def add_new_tags
    key = nil
    [:talent, :profile, :question, :template].each do |p|
      key = p if params[p]
    end
    return if key.nil? || params[key][:tag_ids].blank?
    add_new_data(Tag, params[key], :tag_ids)
  end

  def respond_with(obj, *args)
    if (begin
          obj.errors.blank?
        rescue
          true
        end)
      super
    else
      render_errors obj
    end
  end

  # Number of record to be shown per page is 12.
  PER_PAGE = 12

  def per_page
    params[:per_page] || 12
  end

  def page_count
    params[:page] || 1
  end

  def require_no_authentication
    assert_is_devise_resource!
    return unless is_navigational_format?
    no_input = devise_mapping.no_input_strategies

    authenticated = if no_input.present?
                      args = no_input.dup.push scope: resource_name
                      warden.authenticate?(*args)
                    else
                      warden.authenticated?(resource_name)
                    end

    if authenticated && resource = warden.user(resource_name)
      flash[:alert] = I18n.t('devise.failure.already_authenticated')
      redirect_to after_sign_in_path_for(resource)
    end
  end

  def set_headers
    if request.headers['HTTP_ORIGIN']
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Expose-Headers'] = 'ETag'
      headers['Access-Control-Allow-Methods'] = 'GET, POST, PATCH, PUT, DELETE, OPTIONS, HEAD'
      headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept, Authorization, Token, TempAuthorization'
      headers['Access-Control-Max-Age'] = '1728000'
      headers['Access-Control-Allow-Credentials'] = 'true'
    end
  end

  def check_options_and_return
    if request.request_method.eql?('OPTIONS')
      render json: '',
             status: :ok
    end
  end

  def authenticate_user!
    respond_to do |format|
      format.html { super }
      format.json { unauthorized! unless current_user }
      format.pdf { unauthorized! unless current_user }
      format.docx { unauthorized! unless current_user }
      format.csv { unauthorized! unless current_user }
      format.ics { unauthorized! unless current_user }
    end
  end

  def current_user
    respond_to do |format|
      format.html { super }
      format.json { @current_user ||= set_current_user }
      format.pdf { @current_user ||= set_current_user }
      format.docx { @current_user ||= set_current_user }
      format.csv { @current_user ||= set_current_user }
      format.ics { @current_user ||= set_current_user }
    end
  end

  def authenticate_talent!
    respond_to do |format|
      format.html { super }
      format.json { unauthorized! unless current_talent }
      format.pdf { unauthorized! unless current_talent }
      format.docx { unauthorized! unless current_talent }
      format.csv { unauthorized! unless current_talent }
      format.ics { unauthorized! unless current_user }
    end
  end

  def current_talent
    respond_to do |format|
      format.html { super }
      format.json { @current_talent ||= set_current_talent }
      format.pdf { @current_talent ||= set_current_talent }
      format.docx { @current_talent ||= set_current_talent }
      format.csv { @current_talent ||= set_current_talent }
      format.ics { @current_talent ||= set_current_talent }
    end
  end

  def check_for_valid_action
    return if request.headers["Authorization"].present? ||
      @current_talent ||
      request.headers["TempAuthorization"].blank?

    valid_action = ['talent/profiles', 'talent/talents_jobs', 'talent/events', 'talent/offer_letters'].include?(params[:controller]) &&
      ['update', 'show', 'view_offer', 'accept_offer', 'reject_offer', 'reject', 'destroy'].include?(params[:action])

    token = request.headers["TempAuthorization"].to_s
    token = token.split(' ').last
    return if token.blank? || valid_action.eql?(false)
    payload = JsonWebToken.new(token)
    @current_talent = Talent.find payload.user_id if payload.valid?
    @current_talent
  end

  Devise.mappings.keys.collect(&:to_s).each do |u|
    define_method "set_current_#{u}" do
      # remove following two lines
      token = request.headers['Authorization'].to_s
      token = token.split(' ').last
      return unless token
      begin
        payload = JsonWebToken.new(token)
        user = u.capitalize.constantize.find(payload.user_id) if payload.valid?
        user = nil unless user.enable
        case user.class.to_s
        when "User"
          @current_user = user
        when "Talent"
          @current_talent = user
        else
          nil
        end

      rescue
        return nil
      end
    end

    define_method "find_#{u}" do
      user = u.capitalize.constantize.find(params["#{u}_id".to_sym])
      case u.class.to_s
      when "User"
        @current_user = user
      when "Talent"
        @current_talent = user
      else
        return render(json: { error: "#{u} not found" }, status: :not_found)
      end

    end
  end

  def show_authentication_messages
    respond_to do |format|
      format.html { super }
      format.json do
        Devise.mappings.keys.collect(&:to_s).each do |u|
          if eval("@#{u} && @#{u}.errors.any?")
            return render(json: eval("@#{u}.errors"),
                          status: :not_found)
          end
        end
        render json: { success: true }, status: :created
      end
    end
  end

  def unauthorized!
    head :unauthorized
  end

  def unmatchd_routes
    render(json: { error: "This page doesn't exist." }, status: :not_found)
  end

  def send_403!
    render(json: { error: "This page doesn't exist." }, status: :forbidden)
  end

  rescue_from CanCan::AccessDenied do |exception|
    render(json: { error: 'You are not authorized to access this page' },
           status: :forbidden, layout: false)
  end

  def parameter_missing(error)
    render json: { error: error.message }, status: :bad_request
  end

  def loggedout(error)
    render json: { error: error.message + '. You need to login again.' },
           status: :unauthorized
  end

  # catch all email exception.
  def handle_email_exception(error)
    Logger.info 'Email not Sent:'
    Logger.info error
  end

  # options={} added due to search result use will_paginate by default.
  # REMOVE when we move everything to jbuilder
  def page_json(obj, options = {})
    {
      per_page: params[:per_page] || PER_PAGE,
      page: params[:page] || 1,
      total_pages: options[:total_pages] || obj.total_pages,
      total: options[:total_count] || obj.total_count,
    }
  end

  def get_user_agent
    proxies = request.env['action_dispatch.remote_ip'].instance_variable_get(:@proxies)
    browser = Browser.new(request.user_agent, accept_language: "en-us")
    Thread.current[:user_agent] = {
      browser: browser.name,
      devise: browser.device.name,
      platform: browser.platform.name,
      bot: browser.bot.name,
      ip: request.remote_ip,
      proxies: proxies ? proxies.map(&:to_s) : [],
    }
    Rails.logger.info Thread.current[:user_agent]
  end

  def attach_current_user_to_obj
    u = current_user || current_talent
    Thread.current[:current_user] = (u ? u.id : nil)
  end

  def current_ability
    @current_ability ||= if current_talent
                           Ability.new(current_talent)
                         else
                           Ability.new(current_user)
                         end
  end

  def rtr_not_available
    render(json: { error: ["Can't find any pending invitation. Please try to login and check your candidacy"] }, status: :unprocessable_entity)
  end

  # CRWDPLT-770 Apply Job. Signup & apply or sign in & apply.
  def talents_job_params
    return {} unless params[:talents_job]
    params.
      require(:talents_job).
      permit([:message, :enable_questionnaire] + questionnaire_answers_params)
  end

  # Method used in jobs_controller & talent/jobs_controller.
  # CRWDPLT-770 Apply Job. Signup & apply or sign in & apply.
  # resume[resume_path]
  # talents_job[message]
  def build_resume_and_job_apply(talent, share_link, referrer, existing_talent)
    profile = talent.get_profile_for(share_link.created_by)
    status = profile.present? ? 'Saved' : 'New'

    @shareable = share_link.shareables.find_or_create_by(
      job_id: share_link.shared_id,
      user_id: share_link.created_by_id,
      talent_id: talent&.id,
      referrer: referrer&.humanize,
      yourl_keyword: share_link.yourl_keyword
    )

    @shareable.update_attributes(
      status: status,
      existing_talent: existing_talent,
    )

    if params[:resume].present?
      resume = Resume.new(resume_path: params[:resume][:resume_path])
      resume.uploadable = talent
      resume.save && talent.update(parse_resume: true)
    end

    unless talent.verified
      TalentMailer.account_verify_notify(talent).deliver_later
    end

    #CRWDPLT-9637-As a user who has shared a shareable link for a job I would like to be notified via email when an applicant applies for a job
    ShareableMailer.notify_respective_recruiter(@shareable).deliver_later
    @shareable.create_pusher

    @user = talent
    render 'talents/sign_in'
  end

  # It must be a helper method. Move it to helpers while view optimization.
  def errors(*records)
    records.flatten.collect do |record|
        # [record, record.collect_children].flatten.collect do |child|
      record.errors.full_messages
      # end
    end.flatten.uniq
  end

  def render_errors(*records)
    render(json: { error: errors(*records) }, status: :unprocessable_entity)
  end

  def rtr_params
    params[:rtr][:updated_by_id] = current_user.id
    permitted_fields = rtr_permitted_fields
    permitted_fields.concat([:signed_at]) if params[:action].eql?('submit_offline')
    params.require(:rtr).permit(permitted_fields)
  end

  def rtr_permitted_fields
    offline_array = params[:action].eql?('submit_offline') ? [:signed_at] : []
    offline_array +
    [
      :location,
      :duration,
      :duration_period,
      :salary,
      :hours_per_week,
      :incumbent_bill_rate,
      :incumbent_bill_period,
      :start_date,
      :start_time,
      :end_time,
      :state,
      :state_obj,
      :country,
      :country_obj,
      :city,
      :postal_code,
      :benefits_added,
      :offline,
      :send_as_representer,
      :offline_rtr_doc,
      :body,
      :subject,
      :updated_by_id,
      :timezone_id,
      { benefits: [] },
    ]
  end

  def bad_value
    # MISS(TODO: TEST CASES NOT WRITTEN)
    render(json: { error: 'bad value' }, status: :unprocessable_entity)
  end

  def create_certifications
    parameters = params[:talent] || params[:profile]
    return if parameters.blank?
     parameters[:certifications].reject! do |certificate|
      certificate[:vendor_id].blank? &&
      certificate[:vendor_name].blank? &&
      certificate[:certificate_id].blank? &&
      certificate[:certificate_name].blank?
    end


    parameters[:certifications].
      select{|c| !c.blank?}.each do |certification_data|
      vendor = Vendor.find(certification_data[:vendor_id]) if certification_data[:vendor_id]
      vendor = Vendor.find_or_create_by(name: certification_data[:vendor_name]) if !vendor && certification_data[:vendor_name]
      certificate = vendor.certificates.find(certification_data[:certificate_id]) if certification_data[:certificate_id]
      certificate = vendor.certificates.find_or_create_by(name: certification_data[:certificate_name]) if !certificate && certification_data[:certificate_name] && vendor.present?
      if certificate
        certification_data.merge!({
          vendor_id: vendor.id,
          certificate_id: certificate.id
        })
      else
        render(json: { error: 'Certificate is invalid' }, status: :unprocessable_entity)
      end
    end
  end

  def restrict_recruiter_access
    if current_user&.agency_user? && current_user&.incompleted_profile.any?
      render json: { error: 'We are unable to process your request. Please complete your profile.' },
             status: :forbidden
    end
  end

  def shared_clients_for(user, client_ids)
    attrs = client_ids.map do |cid|
      {
        client_id: cid,
        user_id: user.id,
        role: user.primary_role.parameterize.underscore,
        is_primary: false
      }
    end

    Assignable.bulk_import(attrs)
    ReindexObjectJob.set(wait: 5.seconds).perform_later(Buyer.where(id: client_ids).to_a)
  end

  def enable_scoutprof?
    true
  end

  def check_valid_subdomains
    return true if request.referer.nil? || !request.referer.match?(/crowdstaffing.com/)

    if request.referer.nil? ||
      !current_url.match(/#{current_base_url_host}/) ||
      allowed_subdomains.include?(current_subdomain) ||
      current_subdomain.match?(/jobs-\w*/)

      return true
    end

    render(json: { error: "This Login URL is Invalid." }, status: 404)
  end

  def allowed_subdomains
    ['app', 'enterprise', 'jobs'] + Agency.all_subdomains
  end

  def filter_subdomain_and_redirect
    access = filter_subdomain_access
    unauthorized! unless access
  end

  def current_url
    @current_url ||= request.referer&.split('/')[2]
  end

  def current_subdomain
    @current_subdomain ||= current_url.gsub('.'+current_base_url_host, '')
  end

  def current_base_url_host
    @current_base_url_host ||= ENV['API3_FE_HOST'].split('/')[2].gsub('app.', '')
  end

  def filter_subdomain_access(user=nil)
    return true if user.is_a?(Talent)
    return true if request.referer.nil? || !request.referer.match?(/crowdstaffing.com/)
    user ||= current_user

    return true unless user

    access = case user.role_group
             when 3
              current_subdomain.eql?('enterprise')
             when 2
              current_subdomain.eql?(user.agency.login_url.split('.')[0]) || current_subdomain.eql?('app')
             when 1
              current_subdomain.eql?('app')
             end
    access
  end

  def fetch_accessible_users_from_params
    user = current_user
    case user.role_group
    when 1
      all_users = User.account_managers.visible_to(user).pluck(:username)
      params[:account_managers] = params[:account_managers].blank? ? [] : (params[:account_managers] & all_users)
    when 2
      all_users = User.visible_to(user).pluck(:username)
      params[:recruiters] = params[:recruiters].blank? ? [] : (params[:recruiters] & all_users)
      params[:recruiters].push(current_user.username) if params[:saved_by_me]
    when 3
      all_users = User.for_hiring_org(user.hiring_organization_id).pluck(:username)
      params[:hiring_managers] = params[:hiring_managers].blank? ? [] : (params[:hiring_managers] & all_users)
    end
  end

  def questionnaire_answers_params
    [
      questionnaire_answers: [
        :id,
        :talent_answer,
        :is_liked,
        :talent_rating,
        {
          options: [
            :value,
            :option_type,
            :is_answer,
            :file_path,
            :is_talent_answer,
            :talent_answer,
            :from_date,
            :to_date,
            :from_num,
            :to_num,
            from_time: [:hours, :minutes, :meridiem],
            to_time: [:hours, :minutes, :meridiem],
          ],
        },
      ],
    ]
  end

  def questions_params
    [
      :id,
      :question,
      :type_of_question,
      :user_id,
      :display_order,
      :page_number,
      :mandatory,
      :score_question,
      :is_date,
      :is_time,
      :is_range,
      :rating_scale,
      :rating_shape,
      :shape_color,
      :is_option_label,
      :_destroy,
      :removed,
      tag_ids: [],
      options: options_params,
    ]
  end

  def options_params
    [:value, :option_type, :is_answer]
  end

  private

  def configure_permitted_parameters
    talent = params[:talent]
    params[:talent][:send_emails] = true if talent
    devise_parameter_sanitizer.permit(:sign_up) do |u|
      user_params = [
        :email,
        :first_name,
        :last_name,
        :avatar,
        :password,
        :send_emails,
        :password_set_by_user,
        phones: [:type, :number, :id, :primary],
      ]

      user_params.concat([
        :city,
        :state,
        :country,
        :postal_code,
        :middle_name,
        :resume_path,
        country_obj: [:id, :name, :abbr],
        state_obj: [:id, :name, :abbr],]
      ) if talent

      u.permit(user_params)
    end
  end
end
v1
