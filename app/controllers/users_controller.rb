class UsersController < ApplicationController
  before_action :set_user, only: [:show, :edit, :update, :destroy]
  before_action :logged_in_user, only: [:edit, :update, :index, :update_password, :reset_otp_key, :demand_otp_key]
  before_action :correct_user, only: [:edit, :update, :update_password, :reset_otp_key, :demand_otp_key]

  # GET /users
  # GET /users.json
  def index
    @user = current_user
    redirect_to @user and return unless @user.admin?
    @users = User.all
  end

  # GET /users/1
  # GET /users/1.json
  def show
    if notice&.include?('successfully created')
      @qr_code = RQRCode::QRCode.new(UserSecurity.find_by_user_id(@user.id).render_otp_key, size: 10, level: :h)
    else
      @qr_code = nil
    end
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edi
  def edit
  end

  # POST /users
  # POST /users.json
  def create
    @user = User.new(user_params)
    @user.credential = SecureRandom.base58(32)
    @user.role = :inactive
    respond_to do |format|
      if @user.save
        LdapService.add_user_entry(@user.user_name, user_params[:password], @user.email)
        UserMailer.activate(@user, activate_user_url(@user)).deliver_later
        format.html {redirect_to @user, notice: 'User was successfully created. Please check your mailbox.'}
        format.json {render :show, status: :created, location: @user}
      else
        format.html {render :new}
        format.json {render json: @user.errors, status: :unprocessable_entity}
      end
    end
  end

  # PATCH/PUT /users/1
  # PATCH/PUT /users/1.json
  def update
    respond_to do |format|
      changeable_params = params.require(:user).permit(:mobile_phone, :emp_id)
      if @user.update(changeable_params)
        format.html {redirect_to @user, notice: 'User was successfully updated.'}
        format.json {render :show, status: :ok, location: @user}
      else
        format.html {render :edit}
        format.json {render json: @user.errors, status: :unprocessable_entity}
      end
    end
  end

  def update_password
    respond_to do |format|
      if @user.authenticate(params[:user][:password]) && @user.update(password: params[:user][:password_new])
        LdapService.set_password(@user.user_name, params[:user][:password_new])
        format.html {redirect_to @user, notice: 'User was successfully updated.'}
        format.json {render :show, status: :ok, location: @user}
      else
        format.html {redirect_to @user, notice: 'Old password wrong!'}
        format.json {render json: @user.errors, status: :unprocessable_entity}
      end
    end
  end

  def reset_otp_key
    @user = User.find_by_email(params[:email])
    if @user && CommonUtils.valid_sign?(@user.email, params[:token], @user.credential, params[:sign])
      sec = UserSecurity.find_by_user_id(@user.id)
      event = AccountEvent.find_by!(user_id: @user.id, finished: false)
      unless event.expired?
        sec.update!(otp_key: ROTP::Base32.random_base32)
        event.update!(finished: true)
        flash[:notice] = 'Your OTP key is successfully created again'
        redirect_to @user
      end
    end
  end

  def demand_otp_key
    if @user.authenticate(params[:user][:password])
      event = AccountEvent.create!(user: @user, event_type: :otp_key_reset)
      UserMailer.otp_key_reset(@user, reset_otp_key_url, event.event_token).deliver_later
      flash[:notice] = 'Please check your email to reset your OTP key'
    else
      flash[:warning] = 'Password wrong'
    end
    redirect_to @user
  end

  # DELETE /users/1
  # DELETE /users/1.json
  def destroy
    @user.destroy
    respond_to do |format|
      format.html {redirect_to users_url, notice: 'User was successfully destroyed.'}
      format.json {head :no_content}
    end
  end

  def activate
    @user = User.find(params[:id])
    if CommonUtils.valid_email_token?('activate', params[:activate_token], @user)
      @user.update!(role: :ordinary)
      flash[:notice] = 'Your account is activated successfully'
    else
      flash[:warning] = 'Failed to activate user'
    end
    redirect_to login_path
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = User.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def user_params
    params.require(:user).permit(:user_name, :emp_id, :mobile_phone, :email, :password)
  end

  # Confirms the correct user.
  def correct_user
    @user = User.find(params[:id])
    redirect_to(root_url) unless current_user?(@user)
  end

  # TODO-impl
  def activate_token
    @user.user_name
  end
end
