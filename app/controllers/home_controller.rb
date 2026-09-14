class HomeController < ApplicationController
  def index
    @current_signature = current_user&.signature_for_current_version
  end
end
