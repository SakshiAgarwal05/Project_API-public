# Overwrite Devise registration controller.
class Api::V1:: SessionsController < Devise::SessionsController
  
  before_action :user_or_talent, only: [:create]

  # login a user
  # ====URL
  #   /users/sign_in [POST]
  #   /talents/sign_in [POST]
  # ====Parameters
  #   user[login]
  #   user[password]
  # for talent
  # ====Parameters
  #   talent[login]
  #   talent[password]
  def create
    build_resource
    access = true
    @user = @class_name.find_for_database_authentication(login: params[@params_name][:login])
    return invalid_login_attempt unless @user

    if @user.is_a?(Talent) && !@user.enable
      return invalid_talent
    end

    # if params[:domain].present? && @user.is_a?(User) && Rails.env.production?
    #   return invalid_crowdstaffer_url(@user) unless @user.check_crowdstaffer_url(params[:domain])
    # end

    access = filter_subdomain_access(@user) if @user.is_a?(User)
    
    if access && @user.valid_password?(params[@params_name][:password])
      sign_in(@params_name.to_s, @user)
      if @user.is_a?(Talent)
        @user.update_contact_by
        render "talents/sign_in"
      else
        render "users/sign_in"
      end
      
      return
    elsif access
      invalid_login_attempt
    else
      unauthorized!
    end
  end

  def is_logged_in
    access = true
    user_or_talent
    @user = @params_name ? send("current_#{@params_name}") : nil

    access = filter_subdomain_access(@user) if @user.is_a?(User)

    # if params[:domain].present? && @user.is_a?(User) && Rails.env.production?
    #   return invalid_crowdstaffer_url(@user) unless @user.check_crowdstaffer_url(params[:domain])
    # end

    if access && @user
      render "#{@user.plural_name}/sign_in"
    elsif access
      render :json => { error: "you need to login" }, status: :unauthorized
    else
      unauthorized!
    end
  end

  # def linkedin
  #   oauth = LinkedIn::OAuth2.new
  #   url = oauth.auth_code_url
  #   begin
  #     access_token = oauth.get_access_token(params[:code])
  #     api = LinkedIn::API.new(access_token)
  #     talent_info = api.profile(fields: ['id', 'email-address', 'summary', 'positions','first-name', 'last-name', 'headline', 'location', 'industry', 'picture-urls::(original)', 'public-profile-url'])
  #     talent = create_talent(talent_info)
  #     if talent.present?
  #       @user = talent
  #       render "talents/sign_in"
  #     else
  #       invalid_talent
  #     end
  #   rescue => e
  #     render json: {error: e.message}, status: 422
  #   end
  # end

  private

  def build_resource(hash=nil)
    self.resource = resource_class.new_with_session(hash || {}, session)
  end

  def invalid_login_attempt
    render json: {
      error: ["Error with your login or password"]
    }, status: :unauthorized
  end

  def user_or_talent
    @params_name = request.env["devise.mapping"].scoped_path.singularize
    @class_name = [User, Talent].find do |class_name|
      class_name.name == @params_name.capitalize.to_s
    end
  end

  def create_talent(talent_info)
    if talent = Talent.where(email: talent_info.email_address).last
    else
      talent = Talent.create(email: talent_info.email_address, first_name: talent_info.first_name, last_name: talent_info.last_name)
    end
    talent.enable ? talent.update_talent_info(talent_info) : false
  end

  def invalid_talent
    render json: { error: 'Your account is disabled, please contact system admin' }, status: 422
  end

  # def invalid_crowdstaffer_url(user)
  #   crowdstaffer_url = user.hiring_org_user? ? FE_HOST.gsub(/app\./, 'enterprise.') : user.front_end_host

  #   render json: {
  #     error: "You are not authorized to access this page.
  #       Please visit #{crowdstaffer_url}",
  #   }, status: :forbidden
  # end
end
