class SessionsController < ApplicationController
  rescue_from HackClubAuth::Error, with: :oauth_error

  def new
    state = SecureRandom.hex(32)
    session[:oauth_state] = state
    redirect_to HackClubAuth.authorization_url(state: state), allow_other_host: true
  end

  def callback
    expected_state = session.delete(:oauth_state).to_s
    unless params[:state].present? && expected_state.present? &&
        ActiveSupport::SecurityUtils.secure_compare(params[:state], expected_state)
      return redirect_to root_path, alert: "That login request expired or was invalid. Please try again."
    end

    identity = HackClubAuth.identity_for(params.require(:code))
    user = User.find_or_initialize_by(hack_club_identity_id: identity.fetch("id"))
    user.update!(
      slack_id: identity.fetch("slack_id"),
      first_name: identity["first_name"],
      last_name: identity["last_name"],
      email: identity["primary_email"]
    )
    reset_session
    session[:user_id] = user.id
    redirect_to nda_signature_path, notice: "Signed in successfully."
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "You have been signed out."
  end

  private

  def oauth_error(error)
    Rails.logger.warn("Hack Club OAuth failed: #{error.message}")
    redirect_to root_path, alert: "We couldn't sign you in with Hack Club. Please try again."
  end
end
