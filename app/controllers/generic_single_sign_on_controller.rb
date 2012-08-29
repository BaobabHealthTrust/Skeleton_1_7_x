class GenericSingleSignOnController < ApplicationController

	def get_token
		user = User.authenticate(params[:login], params[:password]) rescue nil
		sign_in(:user, user) if user
		authenticate_user! if user
		user_token = nil
		if !user.blank?
			if current_user.authentication_token.blank?
				current_user.reset_authentication_token 
			end
			user_token = current_user.authentication_token
			current_user.save!
			render :json => {:auth_token => current_user.authentication_token }.to_json, :status => :ok
		else
			render :json => {:auth_token => '' }.to_json, :status => :false
		end
	end

	def single_sign_in
		if params[:return_uri].blank?
			session[:return_uri] = '/'
		else
			session[:return_uri] = params[:return_uri]
		end

		if !params[:current_time].blank?
			session[:datetime] = params[:current_time].to_time
		end

				
		session[:location_id] = params[:location] if params[:location]
		session[:ssolocation] = params[:location] if params[:location]
		
		logger.info(session.to_s) if session[:sso_location]
		if params[:destination_uri].blank?
			redirect_to '/' 
		else
			redirect_to "/single_sign_on/load_page?return_uri=#{params[:return_uri]}&location=#{params[:location]}&destination_uri=#{params[:destination_uri]}" 
		end

		return
	end

	def load_page
		redirect_to params[:destination_uri]
	end

end
