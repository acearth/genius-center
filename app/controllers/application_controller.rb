class ApplicationController < ActionController::Base
  include SessionsHelper
  # protect_from_forgery with: :exception
  before_action :set_locale
  protect_from_forgery

  # Confirms a logged-in user.
  def logged_in_user
    unless logged_in?
      store_location
      flash[:danger] = "Please log in."
      redirect_to login_url
    end
  end

  def set_locale
    I18n.locale = http_accept_language.compatible_language_from(I18n.available_locales)
    I18n.locale = params[:locale] if params[:locale]
    # cookies[:locale] = params[:locale] || cookies[:locale] || I18n.default_locale
    # I18n.locale = cookies[:locale]
  end
end