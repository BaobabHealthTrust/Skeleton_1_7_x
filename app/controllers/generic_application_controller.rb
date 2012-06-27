class GenericApplicationController < ActionController::Base
		Mastercard
		PatientIdentifierType
		PatientIdentifier
		PersonAttribute
		PersonAttributeType
		WeightHeight
		CohortTool
		Encounter
		EncounterType
		Location
		DrugOrder
		User
		Task
		GlobalProperty
		Person
		Regimen
		Relationship
		ConceptName
		Concept
		Settings
	require "fastercsv"

	helper :all
	helper_method :next_task
	filter_parameter_logging :password
	before_filter :authenticate_user!, :except => ['login', 'logout','remote_demographics',
		                                      'create_remote', 'mastercard_printable', 'get_token']

    before_filter :set_current_user, :except => ['login', 'logout','remote_demographics',
		                                      'create_remote', 'mastercard_printable', 'get_token']

	before_filter :location_required, :except => ['login', 'logout', 'location',
		                                        'demographics','create_remote',
		                                         'mastercard_printable',
		                                        'remote_demographics', 'get_token', 'single_sign_in']
  
	def rescue_action_in_public(exception)
		@message = exception.message
		@backtrace = exception.backtrace.join("\n") unless exception.nil?
		logger.info @message
		logger.info @backtrace
		render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
	end if RAILS_ENV == 'development' || RAILS_ENV == 'test'

  def rescue_action(exception)
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    logger.info @message
    logger.info @backtrace
    render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'production'

  def print_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    @patient_id = patient_id
    render :template => 'print/print', :layout => nil
  end
  
  def print_location_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    render :template => 'print/print_location', :layout => nil
  end

  def show_lab_results
    CoreService.get_global_property_value('show.lab.results').to_s == "true" rescue false
  end

  def use_filing_number
    CoreService.get_global_property_value('use.filing.number').to_s == "true" rescue false
  end 
 
 def generic_locations
  field_name = "name"

  Location.find_by_sql("SELECT *
          FROM location
          WHERE location_id IN (SELECT location_id
                         FROM location_tag_map
                          WHERE location_tag_id = (SELECT location_tag_id
                                 FROM location_tag
                                 WHERE name = 'Workstation Location'))
             ORDER BY name ASC").collect{|name| name.send(field_name)} rescue []
  end

  def site_prefix
    site_prefix = CoreService.get_global_property_value("site_prefix") rescue false
    return site_prefix
  end

	def use_user_selected_activities
		CoreService.get_global_property_value('use.user.selected.activities').to_s == "true" rescue false
	end
  
  def tb_dot_sites_tag
    CoreService.get_global_property_value('tb_dot_sites_tag') rescue nil
  end

  def create_from_remote                                                        
    CoreService.get_global_property_value('create.from.remote').to_s == "true" rescue false
  end

  def create_from_dde_server                                                    
    CoreService.get_global_property_value('create.from.dde.server').to_s == "true" rescue false
  end

  def concept_set(concept_name)
    concept_id = ConceptName.find_by_name(concept_name).concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

	return options
  end

  def concept_set_diff(concept_name, exclude_concept_name)
    concept_id = ConceptName.find_by_name(concept_name).concept_id
    
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

    exclude_concept_id = ConceptName.find_by_name(exclude_concept_name).concept_id
    exclude_set = ConceptSet.find_all_by_concept_set(exclude_concept_id, :order => 'sort_weight')
    exclude_options = exclude_set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

    final_options = (options - exclude_options)
	return final_options
  end


  def next_task(patient)
    session_date = session[:datetime].to_date rescue Date.today
    task = nil
    begin
      return task.url if task.present? && task.url.present?
      return "/patients/show/#{patient.id}" 
    rescue
      return "/patients/show/#{patient.id}" 
    end
  end

  def current_user_roles
    user_roles = UserRole.find(:all,:conditions =>["user_id = ?", current_user.id]).collect{|r|r.role}
    RoleRole.find(:all,:conditions => ["child_role IN (?)", user_roles]).collect{|r|user_roles << r.parent_role}
    return user_roles.uniq
  end

  def current_program_location
    current_user_activities = current_user.activities
    if Location.current_location.name.downcase == 'outpatient'
      return "OPD"
    elsif current_user_activities.include?('Manage Lab Orders') or current_user_activities.include?('Manage Lab Results') or
       current_user_activities.include?('Manage Sputum Submissions') or current_user_activities.include?('Manage TB Clinic Visits') or
       current_user_activities.include?('Manage TB Reception Visits') or current_user_activities.include?('Manage TB Registration Visits') or
       current_user_activities.include?('Manage HIV Status Visits')  
       return 'TB program'
    else #if current_user_activities
       return 'HIV program'
    end
  end

    def location_required
      if not located? and params[:location]
        location = Location.find(params[:location]) rescue nil
        self.current_location = location if location
      end
      located? || location_denied
    end

    def located?
      
      self.current_location
    end

    # Redirect as appropriate when an access request fails.
    #
    # The default action is to redirect to the location screen.
    def location_denied
      respond_to do |format|
        format.html do
          store_location
          redirect_to '/location'
        end
      end
    end

    # Store the URI of the current request in the session.
    #
    # We can return to this location by calling #redirect_back_or_default.
    def store_location
      session[:return_to] = request.request_uri
    end

    # Redirect to the URI stored by the most recent store_location call or
    # to the passed default.  Set an appropriately modified
    #   after_filter :store_location, :only => [:index, :new, :show, :edit]
    # for any controller you want to be bounce-backable.
    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end

    # Accesses the current user from the session.
    # Future calls avoid the database because nil is not equal to false.
    def current_location
      @current_location ||= location_from_session unless @current_location == false
      Location.current_location = @current_location unless @current_location == false
      @current_location
    end

    # Store the given location id in the session.
    def current_location=(new_location)
      session[:location_id] = new_location ? new_location.id : nil
      @current_location = new_location || false
    end

    # Called from #current_location.  First attempt to get the location id stored in the session.
    def location_from_session
      self.current_location = Location.find_by_location_id(session[:location_id]) if session[:location_id]
    end

    def set_current_user
      User.current = current_user
    end


private

  def find_patient
    @patient = Patient.find(params[:patient_id] || session[:patient_id] || params[:id]) rescue nil
  end

  def has_patient_been_on_art_before(patient)
	on_art = false
    patient_states = PatientProgram.find(:first, :conditions => ["program_id = ? AND location_id = ? AND patient_id = ?",      
      Program.find_by_concept_id(Concept.find_by_name('HIV PROGRAM').id).id, 
      Location.current_health_center,patient.id]).patient_states rescue []

    (patient_states || []).each do |state|
      if state.program_workflow_state.concept.fullname.match(/antiretrovirals/i)
        on_art = true
      end
    end
    return on_art
  end
end
