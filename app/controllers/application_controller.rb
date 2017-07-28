require 'redirect_with_see_other'
require 'user_session'
require 'user_errors'

class ApplicationController < ActionController::Base
  include UserSession
  include UserErrors
  before_action :validate_session
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :set_locale
  before_action { OriginatingIpStore.store(request) }
  after_action :store_locale_in_cookie, if: -> { request.method == 'GET' }
  helper_method :transactions_list
  helper_method :loa1_transactions_list
  helper_method :loa2_transactions_list

  rescue_from StandardError, with: :something_went_wrong unless Rails.env == 'development'
  rescue_from Errors::WarningLevelError, with: :something_went_wrong_warn
  rescue_from Api::SessionError, with: :session_error
  rescue_from Api::UpstreamError, with: :something_went_wrong_warn
  rescue_from Api::SessionTimeoutError, with: :session_timeout

  prepend RedirectWithSeeOther

  def set_secure_cookie(name, value)
    cookies[name] = {
        value: value,
        httponly: true,
        secure: Rails.configuration.x.cookies.secure
    }
  end
end
