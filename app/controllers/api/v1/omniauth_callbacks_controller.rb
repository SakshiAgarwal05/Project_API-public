# controller for logging in with linked in.
class Api::V1:: OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def self.provides_callback_for(provider)
    class_eval %Q{
      def #{provider}
        @user = Talent.find_for_oauth(env["omniauth.auth"], current_user)
        if @user.persisted? && @user.valid?
          resource.ensure_authentication_token!
          render :json=> {:success=>true, user: resource}
        else
          render :json=> {:error => "Error with your login or password"}, :status=>401
        end
      end
    }
  end

  [:linkedin].each do |provider|
    provides_callback_for provider
  end

  def after_sign_in_path_for(resource)
    if resource.email_verified?
      super resource
    else
      finish_signup_path(resource)
    end
  end
end


