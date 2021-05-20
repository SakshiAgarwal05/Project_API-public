class Api::V1:: PasswordsController < Devise::SessionsController

  def create
    self.resource = resource_class.reset_password(params[:user][:email] || params[:talent][:email])
    if resource
      access = true
      access = filter_subdomain_access(resource) if resource.is_a?(User)
      yield resource if block_given?
      if access && !resource.can_reset_password?
        render json: { error: 'Unable to reset password, your account is disabled' }, status: 422
      elsif access && successfully_sent?(resource)
        if resource.confirmed?
          render json: {notice: t('.confirmed')}, status: :ok
        else
          render json: {notice: t('.refute')}, status: :ok
        end
      elsif access
        render_errors resource
      else
        unauthorized!
      end
    else
      render json: { error: ['Email not found.'] }, status: :unprocessable_entity
    end
  end

  # PUT /resource/password
  def update
    self.resource = resource_class.reset_password_by_token(resource_params)
    access = true
    access = filter_subdomain_access(resource) if resource.is_a?(User)
    yield resource if block_given?
    if access && resource.errors.empty?
      @user = resource
      render "#{@user.plural_name}/sign_in"
    elsif access
      if resource.errors.include?(:password) || resource_params.nil?
        render_errors resource
      elsif resource.errors.exclude?(:password) &&
        ([
          'Reset password token is invalid',
          'Your account is not yet confirmed. Request for a confirmation email for your account.',
        ] & resource.errors.full_messages
        ).empty?
        resource.save(validate: false)
        @user = resource
        render "#{@user.plural_name}/sign_in"
      else
        render_errors resource
      end
    else
      unauthorized!
    end
  end

  # GET /resource/check_if_organization_active
  def check_if_organization_active
    token = params.permit(:reset_password_token)
    self.resource = resource_class.with_reset_password_token(token[:reset_password_token])

    if resource && resource.reset_password_period_valid? && resource.can_reset_password?
      render json: { message: 'success' }, status: 200
    else
      unauthorized!
    end
  end

  private

  def resource_params
    return params.require(:user).permit(:reset_password_token, :password, :email) if params[:user]
    return params.require(:talent).permit(:reset_password_token, :password, :email) if params[:talent]
  end
end
