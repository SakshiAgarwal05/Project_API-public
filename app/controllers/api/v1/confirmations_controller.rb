# TODO: TEST CASES NOT WRITTEN
# overwrite devise confirmation controller.
class ConfirmationsController < Devise::ConfirmationsController
  # overwrite default confirmation from devise.
  # ====URL
  #   /talents/confirmation
  #   or
  #   /users/confirmation
  # ====parameters
  # confirmation_token
  def show
    resource = resource_class.find_first_by_auth_conditions(
      confirmation_token: params[:confirmation_token]
      )

    if resource && resource.can_confirm?
      @resource = resource
    elsif resource
      render json: {
        error: errors(resource) + ["You are not authorized to access this page"]
      }, status: 401
    else
      invalid_confirmation_token
    end
  end

  # confirm as well as change the password.
  # ====URL
  #   /talents/confirmation [PUT]
  #   or
  #   /users/confirmation [PUT]
  # ====parameters
  #  confirmation_token
  #  user[avatar]
  #  user[first_name]
  #  user[last_name]
  #  user[headline]
  #  user[username]
  #  user[password]
  #  user[bio]
  #  user[industry_ids][]
  #  user[category_ids][]
  #  user[country_ids][]
  #  user[phones][type]
  #  user[phones][number]
  #  user[phones][id]
  #  user[phones][primary]
  #  user[job_types][]
  def update
    resource = resource_class.find_first_by_auth_conditions(confirmation_token: params[:confirmation_token])
    if resource && resource.persisted?
      send("confirm_account_#{resource.class.to_s.downcase}", resource)
    else
      invalid_confirmation_token
    end
  end

  # to confirm a account with invitation token sent in job invitation
  # ====URL
  # /talents/confirm_with_invitation [POST]
  # ====PARAMETERS
  # invitation_token
  # talent[password]
  def confirm_with_invitation
    @talents_job = TalentsJob.where(
      invitation_token: params[:invitation_token]
    ).first if params[:invitation_token]

    if @talents_job
      resource = @talents_job.talent
      @talents_job.confirm_email
      if resource.confirmed?
        render json: { error: "Your account was already confirmed, please try signing in." }, status: 422
      else
        confirm_account_talent(resource)
      end
    else
      invalid_confirmation_token
    end
  end

  # Get detail of user with invitation_token sent for a job.
  # ====URL
  # /talents/find_user_with_job_invitation?invitation_token=INVITATION_TOKEN [GET]
  # Response Updation -- When talent comes with
  # invitation token make him loggedIn virtually
  def find_user_with_job_invitation
    logger.info("invitation_token: #{params[:invitation_token]}")

    @talents_job = TalentsJob.where(
      invitation_token: params[:invitation_token]
    ).first if params[:invitation_token]
    if @talents_job
      @talents_job.confirm_email
      @user = @talents_job.talent
      render 'talents/sign_in'
    else
      invalid_confirmation_token
    end
  end

  # Without adding this method, resource_class is always Talent.
  def resource_name
    request.fullpath.match(/talents/) ? :talent : :user
  end

  private

  def confirm_and_login(resource)
    if resource.confirm({attributes: user_params})
      user_or_talent
      sign_in(@params_name.to_s, resource)
      @user = resource
      access = filter_subdomain_access(@user)
      if access
        render "#{@user.plural_name}/sign_in"
      else
        unauthorized!
      end
    else
      render_errors resource
    end
  end

  def confirm_account_talent(resource)
    if !resource.password_set_by_user &&
      (params[:talent].blank? || params[:talent][:password].blank?)
      params[:talent][:password] = ''
    end

    confirm_and_login(resource)
  end

  def confirm_account_user(resource)
    if !resource.password_set_by_user &&
      (params[:user].blank? || params[:user][:password].blank?)
      params[:user][:password] = ''
    end

    confirm_and_login(resource)
  end

  def user_or_talent
    @class_name, @params_name = [User, :user] if request.url.match(/users/)
    @class_name, @params_name = [Talent, :talent] if request.url.match(/talents/)
  end

  def user_params
    # at time of confirmation whether it is internal or external we are not
    # accepting any fields other than password and password set by user
    if params[:user].present?
      params[:user][:password_set_by_user] = true
      params.require(:user).permit([:password, :password_set_by_user])
    else
      talent_params
    end
  end

  def talent_params
    params[:talent][:password_set_by_user] = true
    params.require(:talent).permit([:password, :password_set_by_user])
  end

  def invalid_confirmation_token
    render json: { error: "Confirmation token is invalid or expired." }, status: 401
  end

  # TODO: not required. remove it.
  def after_confirmation_path_for(resource_name, resource)
    resource.is_a?(User) ? resource.front_end_host : JOBS_FE_HOST
  end

end
