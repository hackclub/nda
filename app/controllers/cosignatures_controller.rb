class CosignaturesController < ApplicationController
  before_action :no_referrer

  def show
    @signature = Cosignature.find(params[:token])
    render :expired, status: :not_found unless @signature
  end

  def create
    @signature = Cosignature.find(params[:token])
    return render(:expired, status: :not_found) unless @signature

    unless ActiveModel::Type::Boolean.new.cast(params[:accepted])
      return rerender("Please tick the box to agree before signing.")
    end
    unless params[:cosigner_signed_name].to_s.squish.casecmp?(@signature.cosigner_name.to_s.squish)
      return rerender("Please type your name exactly as it appears above: #{@signature.cosigner_name}.")
    end

    Cosignature.countersign!(
      @signature, name: params[:cosigner_signed_name],
      ip: request.remote_ip, user_agent: request.user_agent
    )
    render :done
  rescue Cosignature::AlreadySigned
    render :expired, status: :not_found
  end

  private

  def rerender(message)
    flash.now.alert = message
    render :show, status: :unprocessable_entity
  end

  def no_referrer
    response.set_header("Referrer-Policy", "no-referrer")
    response.set_header("X-Robots-Tag", "noindex, nofollow")
  end
end
