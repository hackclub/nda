class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  helper_method :current_user

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def require_login
    redirect_to root_path, alert: "Please sign in first!" unless current_user
  end

  def require_admin
    redirect_to root_path, alert: "Please sign in first!" unless current_user&.admin?
  end
end
