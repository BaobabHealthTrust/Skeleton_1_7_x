class GenericPatientsController < ApplicationController
	before_filter :find_patient, :except => [:void]
  
	def show
		return_uri = session[:return_uri]
		if !return_uri.blank?
    		redirect_to return_uri.to_s
    		return
		end
		session[:mastercard_ids] = []
		session_date = session[:datetime].to_date rescue Date.today
		@patient_bean = PatientService.get_patient(@patient.person)
		@encounters = @patient.encounters.find_by_date(session_date)
		@diabetes_number = DiabetesService.diabetes_number(@patient)
		@prescriptions = @patient.orders.unfinished.prescriptions.all
		@programs = @patient.patient_programs.all
		@alerts = alerts(@patient, session_date) rescue nil
		@restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		@restricted.each do |restriction|    
			@encounters = restriction.filter_encounters(@encounters)
			@prescriptions = restriction.filter_orders(@prescriptions)
			@programs = restriction.filter_programs(@programs)
		end

		@date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

		@location = Location.find(session[:location_id]).name rescue ""
	

		if @location.downcase == "outpatient" || params[:source]== 'opd'
			render :template => 'dashboards/opdtreatment_dashboard', :layout => false
		else
			@task = main_next_task(Location.current_location,@patient,session_date)
			@hiv_status = PatientService.patient_hiv_status(@patient)
			@reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
			if  !@reason_for_art_eligibility.nil? && @reason_for_art_eligibility.upcase == 'NONE'
				@reason_for_art_eligibility = nil				
			end
			@arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')
			render :template => 'patients/index', :layout => false
		end
	end

  def opdcard
    @patient = Patient.find(params[:id])
    render :layout => 'menu' 
  end

  def opdshow
    session_date = session[:datetime].to_date rescue Date.today
    encounter_types = EncounterType.find(:all,:conditions =>["name IN (?)",
        ['REGISTRATION','OUTPATIENT DIAGNOSIS','REFER PATIENT OUT?','OUTPATIENT RECEPTION','DISPENSING']]).map{|e|e.id}
    @encounters = Encounter.find(:all,:select => "encounter_id , name encounter_type_name, count(*) c",
      :joins => "INNER JOIN encounter_type ON encounter_type_id = encounter_type",
      :conditions =>["patient_id = ? AND encounter_type IN (?) AND DATE(encounter_datetime) = ?",
        params[:id],encounter_types,session_date],
      :group => 'encounter_type').collect do |rec| 
        if current_user.user_roles.map{|r|r.role}.join(',').match(/Registration|Clerk/i)
          next unless rec.observations[0].to_s.match(/Workstation location:   Outpatient/i)
        end
        [ rec.encounter_id , rec.encounter_type_name , rec.c ] 
      end
    
    render :template => 'dashboards/opdoverview_tab', :layout => false
  end

  def opdtreatment
    render :template => 'dashboards/opdtreatment_dashboard', :layout => false
  end

  def opdtreatment_tab
    @activities = [
      ["Visit card","/patients/opdcard/#{params[:id]}"],
      ["National ID (Print)","/patients/dashboard_print_national_id?id=#{params[:id]}&redirect=patients/opdtreatment"],
      ["Referrals", "/encounters/referral/#{params[:id]}"],
      ["Give drugs", "/encounters/opddrug_dispensing/#{params[:id]}"],
      ["Vitals", "/report/data_cleaning"],
      ["Outpatient diagnosis","/encounters/new?id=show&patient_id=#{params[:id]}&encounter_type=outpatient_diagnosis"]
    ]
    render :template => 'dashboards/opdtreatment_tab', :layout => false
  end

  def treatment
    #@prescriptions = @patient.orders.current.prescriptions.all
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
        type.id,@patient.id,session_date])

    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @prescriptions = restriction.filter_orders(@prescriptions)
    end

    @encounters = @patient.encounters.find_by_date(session_date)

    @transfer_out_site = nil

    @encounters.each do |enc|
      enc.observations.map do |obs|
       @transfer_out_site = obs.to_s if obs.to_s.include?('Transfer out to')
     end
    end
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')

    render :template => 'dashboards/dispension_tab', :layout => false
  end

  def history_treatment
    #@prescriptions = @patient.orders.current.prescriptions.all
    @patient = Patient.find(params[:patient_id])
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ?",type.id,@patient.id])

    @historical = @patient.orders.historical.prescriptions.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @historical = restriction.filter_orders(@historical)
    end

    render :template => 'dashboards/treatment_tab', :layout => false
  end

  def guardians
    if @patient.blank?
    	redirect_to :'clinic'
    	return
    else
		  @relationships = @patient.relationships rescue []
		  @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		  @restricted.each do |restriction|
		    @relationships = restriction.filter_relationships(@relationships)
		  end
    	render :template => 'dashboards/relationships_tab', :layout => false
  	end
  end

  def relationships
    if @patient.blank?
    	redirect_to :'clinic'
    	return
    else
      next_form_to = next_task(@patient)
      redirect_to next_form_to and return if next_form_to.match(/Reception/i)
		  @relationships = @patient.relationships rescue []
		  @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		  @restricted.each do |restriction|
		    @relationships = restriction.filter_relationships(@relationships)
		  end
        @patient_arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')
        @patient_bean = PatientService.get_patient(@patient.person)
    	render :template => 'dashboards/relationships', :layout => 'dashboard' 
  	end
  end

  def problems
    render :template => 'dashboards/problems', :layout => 'dashboard' 
  end

  def personal
    @links = []
    patient = Patient.find(params[:id])

    @links << ["Demographics (Print)","/patients/print_demographics/#{patient.id}"]
    @links << ["Visit Summary (Print)","/patients/dashboard_print_visit/#{patient.id}"]
    @links << ["National ID (Print)","/patients/dashboard_print_national_id/#{patient.id}"]
    @links << ["Demographics (Edit)","/people/demographics/#{patient.id}"]

    if use_filing_number and not PatientService.get_patient_identifier(patient, 'Filing Number').blank?
      @links << ["Filing Number (Print)","/patients/print_filing_number/#{patient.id}"]
    end 

    if use_filing_number and PatientService.get_patient_identifier(patient, 'Filing Number').blank?
      @links << ["Filing Number (Create)","/patients/set_filing_number/#{patient.id}"]
    end 

    if use_user_selected_activities
      @links << ["Change User Activities","/user/activities/#{current_user.id}?patient_id=#{patient.id}"]
    end
      
    if show_lab_results
      @links << ["Lab trail", "/lab/results/#{patient.id}"]
    end

    @links << ["Recent Lab Orders Label","/patients/recent_lab_orders?patient_id=#{patient.id}"]
    @links << ["Transfer out label (Print)","/patients/print_transfer_out_label/#{patient.id}"]

    render :template => 'dashboards/personal_tab', :layout => false
  end

  def history
    render :template => 'dashboards/history', :layout => 'dashboard' 
  end

  def programs
    @programs = @patient.patient_programs.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @programs = restriction.filter_programs(@programs)
    end
    flash.now[:error] = params[:error] unless params[:error].blank?

    unless flash[:error].nil?
      redirect_to "/patients/programs_dashboard/#{@patient.id}?error=#{params[:error]}" and return
    else
      render :template => 'dashboards/programs_tab', :layout => false
    end
  end

  def graph
    @currentWeight = params[:currentWeight]
    render :template => "graphs/#{params[:data]}", :layout => false 
  end

  def void 
    @encounter = Encounter.find(params[:encounter_id])
    @encounter.void
    show and return
  end
  
  def print_registration
    print_and_redirect("/patients/national_id_label/?patient_id=#{@patient.id}", next_task(@patient))  
  end
  
  def dashboard_print_national_id
    unless params[:redirect].blank?
      redirect = "/#{params[:redirect]}/#{params[:id]}"
    else
      redirect = "/patients/show/#{params[:id]}"
    end
    print_and_redirect("/patients/national_id_label?patient_id=#{params[:id]}", redirect)  
  end
  
  def dashboard_print_visit
    print_and_redirect("/patients/visit_label/?patient_id=#{params[:id]}", "/patients/show/#{params[:id]}")
  end
  
  def print_visit
    print_and_redirect("/patients/visit_label/?patient_id=#{@patient.id}", next_task(@patient))  
  end

  def print_mastercard_record
    print_and_redirect("/patients/mastercard_record_label/?patient_id=#{@patient.id}&date=#{params[:date]}", "/patients/visit?date=#{params[:date]}&patient_id=#{params[:patient_id]}")
  end

  def print_demographics
    print_and_redirect("/patients/patient_demographics_label/#{@patient.id}", "/patients/show/#{params[:id]}")
  end
 
  def print_filing_number
    print_and_redirect("/patients/filing_number_label/#{params[:id]}", "/patients/show/#{params[:id]}")  
  end
   
  def print_transfer_out_label
    print_and_redirect("/patients/transfer_out_label?patient_id=#{params[:id]}", "/patients/show/#{params[:id]}")  
  end
   
  def patient_demographics_label
    print_string = demographics_label(params[:id])
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:id]}#{rand(10000)}.lbl", :disposition => "inline")
  end
  
  def national_id_label
    print_string = PatientService.patient_national_id_label(@patient) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def print_lab_orders
    patient_id = params[:patient_id]
    patient = Patient.find(patient_id)

    print_and_redirect("/patients/lab_orders_label/?patient_id=#{patient.id}", next_task(patient))
  end

  def lab_orders_label
    patient = Patient.find(params[:patient_id])
    label_commands = patient_lab_orders_label(patient.id)

    send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbs", :disposition => "inline")
  end

  def filing_number_label
    patient = Patient.find(params[:id])
    label_commands = patient_filing_number_label(patient)
    send_data(label_commands,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")
  end
 
  def filing_number_and_national_id
    patient = Patient.find(params[:patient_id])
    label_commands = PatientService.patient_national_id_label(patient) + patient_filing_number_label(patient)

    send_data(label_commands,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")
  end
 
  def visit_label
	session_date = session[:datetime].to_date rescue Date.today
    print_string = patient_visit_label(@patient, session_date) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def specific_patient_visit_date_label
		session_date = params[:session_date].to_date rescue Date.today
    print_string = patient_visit_label(@patient, session_date) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def mastercard_record_label
    print_string = patient_visit_label(@patient, params[:date].to_date)
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def transfer_out_label
    print_string = patient_transfer_out_label(params[:patient_id])
    send_data(print_string,
      :type=>"application/label; charset=utf-8", 
      :stream=> false, 
      :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", 
      :disposition => "inline")
  end

  def mastercard_menu
    render :layout => "menu"
    @patient_id = params[:patient_id]
  end

  def mastercard
    @type = params[:type]
    
    if session[:from_report].to_s == "true"
			@from_report = true
			session[:from_report] = false
    end
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    
    if params[:show_mastercard_counter].to_s == "true" && !params[:current].blank?
			@show_mastercard_counter = true
			session[:mastercard_counter] = params[:current].to_i - 1
      @patient_id = session[:mastercard_ids][session[:mastercard_counter]]
      
      @prev_button_class = "yellow"
      @next_button_class = "yellow"
      
      if params[:current].to_i ==  1
        @prev_button_class = "gray"
      elsif params[:current].to_i ==  session[:mastercard_ids].length
        @next_button_class = "gray"
      end
      
    elsif params[:patient_id].blank?
      @patient_id = session[:mastercard_ids][session[:mastercard_counter]] 
           
    elsif session[:mastercard_ids].length.to_i != 0
      @patient_id = params[:patient_id]
      
    else
      @patient_id = params[:patient_id]
      
    end

    unless params.include?("source")
      @source = params[:source] rescue nil
    else
      @source = nil
    end

    render :layout => false
    
  end

  def mastercard_printable
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    @show_mastercard_counter = false

    if params[:patient_id].blank?

      @show_mastercard_counter = true

      if !params[:current].blank?
        session[:mastercard_counter] = params[:current].to_i - 1
      end
      
      @prev_button_class = "yellow"
      @next_button_class = "yellow"
      if params[:current].to_i ==  1
        @prev_button_class = "gray"
      elsif params[:current].to_i ==  session[:mastercard_ids].length
        @next_button_class = "gray"
      else

      end
      @patient_id = session[:mastercard_ids][session[:mastercard_counter]]
      @data_demo = mastercard_demographics(Patient.find(@patient_id))
      @visits = visits(Patient.find(@patient_id))
      @patient_art_start_date = PatientService.patient_art_start_date(@patient_id)
      # elsif session[:mastercard_ids].length.to_i != 0
      #  @patient_id = params[:patient_id]
      #  @data_demo = mastercard_demographics(Patient.find(@patient_id))
      #  @visits = visits(Patient.find(@patient_id))
    else
      @patient_id = params[:patient_id]
      @patient_art_start_date = PatientService.patient_art_start_date(@patient_id)
      @data_demo = mastercard_demographics(Patient.find(@patient_id))
      @visits = visits(Patient.find(@patient_id))
    end

    @visits.keys.each do|day|
		@age_in_months_for_days[day] = PatientService.age_in_months(@patient.person, day.to_date)
    end rescue nil

    render :layout => false
  end

  def visit
    @patient_id = params[:patient_id] 
    @date = params[:date].to_date
    @patient = Patient.find(@patient_id)
    @patient_bean = PatientService.get_patient(@patient.person)
    @patient_gaurdians = @patient.person.relationships.map{|r| PatientService.name(Person.find(r.person_b)) }.join(' : ')
    @visits = visits(@patient,@date)
    render :layout => "menu"
  end

  def next_available_arv_number
    next_available_arv_number = PatientIdentifier.next_available_arv_number
    render :text => next_available_arv_number.gsub(PatientIdentifier.site_prefix,'').strip rescue nil
  end
  
  def assigned_arv_number
    assigned_arv_number = PatientIdentifier.find(:all,:conditions => ["voided = 0 AND identifier_type = ?",
        PatientIdentifierType.find_by_name("ARV Number").id]).collect{|i| i.identifier.gsub("#{PatientIdentifier.site_prefix}-ARV-",'').strip.to_i} rescue nil
    render :text => assigned_arv_number.sort.to_json rescue nil 
  end

  def mastercard_modify
    if request.method == :get
      @patient_id = params[:id]
      @patient = Patient.find(params[:id])
      @edit_page = edit_mastercard_attribute(params[:field].to_s)

      if @edit_page == "guardian"
        @guardian = {}
        @patient.person.relationships.map{|r| @guardian[art_guardian(@patient)] = Person.find(r.person_b).id.to_s;'' }
        if  @guardian == {}
          redirect_to :controller => "relationships" , :action => "search",:patient_id => @patient_id
        end
      end
    else
      @patient_id = params[:patient_id]
      save_mastercard_attribute(params)
      if params[:source].to_s == "opd"
        redirect_to "/patients/opdcard/#{@patient_id}" and return
      elsif params[:from_demo] == "true"
        redirect_to :controller => "people" ,
        :action => "demographics",:id => @patient_id and return
      else
        redirect_to :action => "mastercard",:patient_id => @patient_id and return
      end
    end
  end

  def summary
    @encounter_type = params[:skipped]
    @patient_id = params[:patient_id]
    render :layout => "menu"
  end

  def set_filing_number
    patient = Patient.find(params[:id])
   PatientService.set_patient_filing_number(patient)

    archived_patient = PatientService.patient_to_be_archived(patient)
    message = PatientService.patient_printing_message(patient,archived_patient,true)
    unless message.blank?
      print_and_redirect("/patients/filing_number_label/#{patient.id}" , "/patients/show/#{patient.id}",message,true,patient.id)
    else
      print_and_redirect("/patients/filing_number_label/#{patient.id}", "/patients/show/#{patient.id}")
    end
  end

  def set_new_filing_number
    patient = Patient.find(params[:id])
    set_new_patient_filing_number(patient)
    archived_patient = PatientService.patient_to_be_archived(patient)
    message = PatientService.patient_printing_message(patient, archived_patient)
    unless message.blank?
      print_and_redirect("/patients/filing_number_label/#{patient.id}" , "/people/confirm?found_person_id=#{patient.id}",message,true,patient.id)
    else
      print_and_redirect("/patients/filing_number_label/#{patient.id}", "/people/confirm?found_person_id=#{patient.id}")
    end
  end

  def export_to_csv
    ( Patient.find(:all,:limit => 10) || [] ).each do | patient |
      patient_bean = PatientService.get_patient(patient.person)
      csv_string = FasterCSV.generate do |csv|
        # header row
        csv << ["ARV number", "National ID"]
        csv << [PatientService.get_patient_identifier(patient, 'ARV Number'), PatientService.get_national_id(patient)]
        csv << ["Name", "Age","Sex","Init Wt(Kg)","Init Ht(cm)","BMI","Transfer-in"]
        transfer_in = patient.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
        transfer_in.blank? == true ? transfer_in = 'NO' : transfer_in = 'YES'
        csv << [patient.person.name,patient.person.age, PatientService.sex(patient.person),PatientService.get_patient_attribute_value(patient, "initial_weight"),PatientService.get_patient_attribute_value(patient, "initial_height"),PatientService.get_patient_attribute_value(patient, "initial_bmi"),transfer_in]
        csv << ["Location", "Land-mark","Occupation","Init Wt(Kg)","Init Ht(cm)","BMI","Transfer-in"]

=begin
        # data rows
        @users.each do |user|
          csv << [user.id, user.username, user.salt]
        end
=end
      end
      # send it to the browsah
      send_data csv_string.gsub(' ','_'),
        :type => 'text/csv; charset=iso-8859-1; header=present',
        :disposition => "attachment:wq
              ; filename=patient-#{patient.id}.csv"
    end
  end

  def print_mastercard
    if @patient
      t1 = Thread.new{
        Kernel.system "htmldoc --webpage --landscape --linkstyle plain --left 1cm --right 1cm --top 1cm --bottom 1cm -f /tmp/output-" +
          current_user.user_id.to_s + ".pdf http://" + request.env["HTTP_HOST"] + "\"/patients/mastercard_printable?patient_id=" +
          @patient.id.to_s + "\"\n"
      }

      t2 = Thread.new{
        sleep(5)
        Kernel.system "lpr /tmp/output-" + current_user.user_id.to_s + ".pdf\n"
      }

      t3 = Thread.new{
        sleep(10)
        Kernel.system "rm /tmp/output-" + current_user.user_id.to_s + ".pdf\n"
      }

    end
    
    redirect_to request.request_uri.to_s.gsub('print_mastercard', 'mastercard') and return
  end
  
  def demographics
	  @patient_bean = PatientService.get_patient(@patient.person)
    render :layout => false
  end
   
  def index
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
    @alerts = alerts(@patient, session_date)
    # This code is pretty hacky at the moment
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")
    @task = main_next_task(Location.current_location,@patient,session_date)
    
    @hiv_status = PatientService.patient_hiv_status(@patient)
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')

    render :template => 'patients/index', :layout => false
  end

  def overview
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
    @alerts = alerts(@patient, session_date) rescue nil
    # This code is pretty hacky at the moment
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end

    render :template => 'dashboards/overview_tab', :layout => false
  end

  def visit_history
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
	start_date = session_date.strftime('%Y-%m-%d 00:00:00')
	end_date = session_date.strftime('%Y-%m-%d 23:59:59')
    @encounters = Encounter.find(:all, 	:conditions => [" patient_id = ? AND encounter_datetime >= ? AND encounter_datetime <= ?", @patient.id, start_date, end_date]) 
    
    @creator_name = {}
    @encounters.each do |encounter|
    	id = encounter.creator
			user_name = User.find(id).person.names.first
			@creator_name[id] = '(' + user_name.given_name.first + '. ' + user_name.family_name + ')'
    end
    
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
    @alerts = alerts(@patient, session_date) rescue nil
    # This code is pretty hacky at the moment
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end

    render :template => 'dashboards/visit_history_tab', :layout => false
  end

   def get_previous_encounters(patient_id)
     session_date = (session[:datetime].to_date rescue Date.today.to_date) - 1.days
     session_date = session_date.to_s + ' 23:59:59'
    previous_encounters = Encounter.find(:all,
              :conditions => ["encounter.voided = ? and patient_id = ? and encounter.encounter_datetime <= ?", 0, patient_id, session_date],
              :include => [:observations],:order => "encounter.encounter_datetime DESC"
            )

    return previous_encounters
  end

  def past_visits_summary
    @previous_visits  = get_previous_encounters(params[:patient_id])

    @encounter_dates = @previous_visits.map{|encounter| encounter.encounter_datetime.to_date}.uniq.first(6) rescue []

    @past_encounter_dates = @encounter_dates

    render :template => 'dashboards/past_visits_summary_tab', :layout => false
  end

  def treatment_dashboard
	  @patient_bean = PatientService.get_patient(@patient.person)
    @amount_needed = 0
    @amounts_required = 0

    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
        type.id,@patient.id,session_date]).each{|order|
      
      @amount_needed = @amount_needed + (order.drug_order.amount_needed.to_i rescue 0)

      @amounts_required = @amounts_required + (order.drug_order.total_required rescue 0)

    }

    @dispensed_order_id = params[:dispensed_order_id]
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')

    render :template => 'dashboards/treatment_dashboard', :layout => false
  end

  def guardians_dashboard
	  @patient_bean = PatientService.get_patient(@patient.person)
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')

    render :template => 'dashboards/relationships_dashboard', :layout => false
  end

  def programs_dashboard
	  @patient_bean = PatientService.get_patient(@patient.person)
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')
    render :template => 'dashboards/programs_dashboard', :layout => false
  end

  def general_mastercard
    @type = nil
    
    case params[:type]
    when "1"
      @type = "yellow"
    when "2"
      @type = "green"
    when "3"
      @type = "pink"
    when "4"
      @type = "blue"
    end

    @mastercard = mastercard_demographics(@patient)
    @patient_art_start_date = PatientService.patient_art_start_date(@patient.id)
    @visits = visits(@patient)   # (@patient, (session[:datetime].to_date rescue Date.today))
    
    @age_in_months_for_days = {}
    @visits.keys.each do|day|
		@age_in_months_for_days[day] = PatientService.age_in_months(@patient.person, day.to_date)
    end
    
    @patient_age_at_initiation = PatientService.patient_age_at_initiation(@patient,
                                              PatientService.patient_art_start_date(@patient.id))
                                              
    @patient_bean = PatientService.get_patient(@patient.person)
		@guardian_phone_number = PatientService.get_attribute(Person.find(@patient.person.relationships.first.person_b), 'Cell phone number') rescue nil
	@patient_phone_number = PatientService.get_attribute(@patient.person, 'Cell phone number')
    render :layout => false
  end

  def patient_details
    render :layout => false
  end

  def status_details
    render :layout => false
  end

  def mastercard_details
    render :layout => false
  end

  def mastercard_header
    render :layout => false
  end

  def number_of_booked_patients
    date = params[:date].to_date
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id
    count = Observation.count(:all,
            :joins => "INNER JOIN encounter e USING(encounter_id)",:group => "value_datetime",
            :conditions =>["concept_id = ? AND encounter_type = ? AND value_datetime >= ? AND value_datetime <= ?",
            concept_id,encounter_type.id,date.strftime('%Y-%m-%d 00:00:00'),date.strftime('%Y-%m-%d 23:59:59')])
    count = count.values unless count.blank?
    count = '0' if count.blank?
    render :text => count
  end

  def recent_lab_orders_print
    patient = Patient.find(params[:id])
    lab_orders_label = params[:lab_tests].split(":")

    label_commands = recent_lab_orders_label(lab_orders_label, patient)
    send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbs", :disposition => "inline")
  end

  def print_recent_lab_orders_label
    #patient = Patient.find(params[:id])
    lab_orders_label = params[:lab_tests].join(":")

    #raise lab_orders_label.to_s
    #label_commands = patient.recent_lab_orders_label(lab_orders_label)
    #send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")

    print_and_redirect("/patients/recent_lab_orders_print/#{params[:id]}?lab_tests=#{lab_orders_label}" , "/patients/show/#{params[:id]}")
  end

  def recent_lab_orders
    patient = Patient.find(params[:patient_id])
    @lab_order_labels = get_recent_lab_orders_label(patient.id)
    @patient_id = params[:patient_id]
  end

  def next_task_description
    @task = Task.find(params[:task_id]) rescue Task.new
    render :template => 'dashboards/next_task_description', :layout => false
  end

  def tb_treatment_card # to look at later - To test that is
  	@patient_bean = PatientService.get_patient(@patient.person)
    render :layout => 'menu'
  end

  def alerts(patient, session_date = Date.today) 
    # next appt
    # adherence
    # drug auto-expiry
    # cd4 due
	patient_bean = PatientService.get_patient(patient.person)
    alerts = []

    type = EncounterType.find_by_name("APPOINTMENT")
    
    @show_change_app_date = Observation.find(:first,                          
    :order => "encounter_datetime DESC,encounter.date_created DESC",          
    :joins => "INNER JOIN encounter ON obs.encounter_id = encounter.encounter_id",
    :conditions => ["concept_id = ? AND encounter_type = ? AND patient_id = ?
    AND encounter_datetime >= ? AND encounter_datetime <= ?",
    ConceptName.find_by_name('Appointment date').concept_id,                  
    type.id, patient.id,session_date.strftime("%Y-%m-%d 00:00:00"),
    session_date.strftime("%Y-%m-%d 23:59:59")]) != nil                    

    next_appt = Observation.find(:first,:order => "encounter_datetime DESC,encounter.date_created DESC",
               :joins => "INNER JOIN encounter ON obs.encounter_id = encounter.encounter_id",
               :conditions => ["concept_id = ? AND encounter_type = ? AND patient_id = ?
               AND obs_datetime <= ?",ConceptName.find_by_name('Appointment date').concept_id,
               type.id,patient.id,session_date.strftime("%Y-%m-%d 23:59:59")
               ]).value_datetime.strftime("%a %d %B %Y") rescue nil
    alerts << ('Next appointment: ' + next_appt) unless next_appt.blank?

    encounter_dates = Encounter.find_by_sql("SELECT * FROM encounter WHERE patient_id = #{patient.id} AND encounter_type IN (" +
        ("SELECT encounter_type_id FROM encounter_type WHERE name IN ('VITALS', 'TREATMENT', " +
          "'HIV RECEPTION', 'HIV STAGING', 'HIV CLINIC CONSULTATION', 'DISPENSING')") + ")").collect{|e|
      e.encounter_datetime.strftime("%Y-%m-%d")
    }.uniq

    missed_appt = patient.encounters.find_last_by_encounter_type(type.id, 
      :conditions => ["NOT (DATE_FORMAT(encounter_datetime, '%Y-%m-%d') IN (?)) AND encounter_datetime < NOW()",
        encounter_dates], :order => "encounter_datetime").observations.last.to_s rescue nil
    alerts << ('Missed ' + missed_appt).capitalize unless missed_appt.blank?

    @adherence_level = ConceptName.find_by_name('What was the patients adherence for this drug order').concept_id
    type = EncounterType.find_by_name("ART ADHERENCE")

    observations = Observation.find(:all,:joins =>"INNER JOIN encounter e USING(encounter_id)",
      :conditions =>["concept_id = ? AND encounter_type = ? AND patient_id = ? AND 
      encounter_datetime >= ? AND encounter_datetime <= ?",@adherence_level,type,
      patient.id,session_date.strftime("%Y-%m-%d 00:00:00"),session_date.strftime("%Y-%m-%d 23:59:59")],
      :order => "obs_datetime DESC")

    (observations || []).map do |adh|
      adherence = adh.value_numeric ||= adh.value_text
      if (adherence.to_f >= 95 || adherence.to_f <= 105)
        drug_name = adh.order.drug_order.drug.concept.shortname rescue adh.order.drug_order.drug.name
        alerts << "Adherence: #{drug_name} (#{adh.value_numeric}%)"
      end
    end 

    type = EncounterType.find_by_name("DISPENSING")
    patient.encounters.find_last_by_encounter_type(type.id, :order => "encounter_datetime").observations.each do | obs |
      next if obs.order.blank? and obs.order.auto_expire_date.blank?
      alerts << "Auto expire date: #{obs.order.drug_order.drug.name} #{obs.order.auto_expire_date.to_date.strftime('%d-%b-%Y')}"
    end rescue []

    # BMI alerts
    if patient_bean.age >= 15
      bmi_alert = current_bmi_alert(PatientService.get_patient_attribute_value(patient, "current_weight"), PatientService.get_patient_attribute_value(patient, "current_height"))
      alerts << bmi_alert if bmi_alert
    end
    
    program_id = Program.find_by_name("HIV PROGRAM").id
    location_id = Location.current_health_center.location_id

    patient_hiv_program = PatientProgram.find(:all,:conditions =>["voided = 0 AND patient_id = ? AND program_id = ? AND location_id = ?", patient.id , program_id, location_id])

    hiv_status = PatientService.patient_hiv_status(patient)
    alerts << "HIV Status : #{hiv_status} more than 3 months" if ("#{hiv_status.strip}" == 'Negative' && PatientService.months_since_last_hiv_test(patient.id) > 3)
    alerts << "Patient not on ART" if (("#{hiv_status.strip}" == 'Positive') && !patient.patient_programs.current.local.map(&:program).map(&:name).include?('HIV PROGRAM')) ||
                                                          ((patient.patient_programs.current.local.map(&:program).map(&:name).include?('HIV PROGRAM')) && (ProgramWorkflowState.find_state(patient_hiv_program.last.patient_states.last.state).concept.fullname != "On antiretrovirals"))
    alerts << "HIV Status : #{hiv_status}" if "#{hiv_status.strip}" == 'Unknown'
    alerts << "Lab: Expecting submission of sputum" unless PatientService.sputum_orders_without_submission(patient.id).empty?
    alerts << "Lab: Waiting for sputum results" if PatientService.recent_sputum_results(patient.id).empty? && !PatientService.recent_sputum_submissions(patient.id).empty?
    alerts << "Lab: Results not given to patient" if !PatientService.recent_sputum_results(patient.id).empty? && given_sputum_results(patient.id).to_s != "Yes"
    alerts << "Patient go for CD4 count testing" if cd4_count_datetime(patient) == true
    alerts << "Lab: Patient must order sputum test" if patient_need_sputum_test?(patient.id)
    alerts << "Refer to ART wing" if show_alert_refer_to_ART_wing(patient)

    alerts
  end

  def cd4_count_datetime(patient)
    session_date = session[:datetime].to_date rescue Date.today
  
  #raise session_date.to_yaml
    hiv_staging = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
          EncounterType.find_by_name("HIV Staging").id,patient.id]) rescue nil

    if !hiv_staging.blank?
      (hiv_staging.observations).map do |obs|
        if obs.concept_id == ConceptName.find_by_name('CD4 count datetime').concept_id
           months = (session_date.year * 12 + session_date.month) - (obs.value_datetime.year * 12 + obs.value_datetime.month) rescue nil
    #raise obs.value_datetime.to_yaml
          if months >= 6
            return true
          else
            return false
          end
        end
      end
    end
  end

  def show_alert_refer_to_ART_wing(patient)
        show_alert = false
        refer_to_x_ray = nil
        does_tb_status_obs_exist = false

	    session_date = session[:datetime].to_date rescue Date.today
        encounter = Encounter.find(:all, :conditions=>["patient_id = ? \
                    AND encounter_type = ? AND DATE(encounter_datetime) = ? ", patient.id, \
                    EncounterType.find_by_name("TB CLINIC VISIT").id, session_date]).last rescue nil
        @date = encounter.encounter_datetime.to_date rescue nil

        if !encounter.nil?
            for obs in encounter.observations do
                if obs.concept_id == ConceptName.find_by_name("Refer to x-ray?").concept_id
                    refer_to_x_ray = "#{obs.to_s(["short", "order"]).to_s.split(":")[1].squish}".squish
                elsif obs.concept_id == ConceptName.find_by_name("TB status").concept_id
                    does_tb_status_obs_exist = true
                end
            end
        end

        if refer_to_x_ray.upcase == 'NO' && does_tb_status_obs_exist.to_s == false.to_s && PatientService.patient_hiv_status(patient).upcase == 'POSITIVE'
           show_alert = true
        end rescue nil
        show_alert
    end

  def patient_need_sputum_test?(patient_id)
    encounter_date = Encounter.find(:last,
                      :conditions => ["encounter_type = ? and patient_id = ?",
                      EncounterType.find_by_name("TB Registration").id,
                      patient_id]).encounter_datetime rescue ''
    smear_positive_patient = false
    has_no_results = false

    unless encounter_date.blank?
      sputum_results = previous_sputum_results(encounter_date, patient_id)
      sputum_results.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Negative").id
            smear_positive_patient = true
            break
        end
      }
      if smear_positive_patient == true
        date_diff = (Date.today - encounter_date.to_date).to_i

        if date_diff > 60 and date_diff < 110
          results = Encounter.find(:last,
                    :conditions => ["encounter_type = ? and " \
                     "patient_id = ? AND encounter_datetime BETWEEN ? AND ?",
                    EncounterType.find_by_name("LAB RESULTS").id,
                     patient_id, (encounter_date + 60).to_s, (encounter_date + 110).to_s],
                   :include => observations) rescue ''

          if results.blank?
            has_no_results = true
          else
            has_no_results = false
          end

        elsif date_diff > 110 and date_diff < 140
          results = Encounter.find(:last,
                    :conditions => ["encounter_type = ? and " \
                     "patient_id = ? AND encounter_datetime BETWEEN ? AND ?",
                    EncounterType.find_by_name("LAB RESULTS").id,
                     patient_id, (encounter_date + 111).to_s, (encounter_date + 140).to_s],
                   :include => observations) rescue ''

          if results.blank?
            has_no_results = true
          else
            has_no_results = false
          end

        elsif date_diff > 140
            has_no_results = true
        else
            has_no_results = false
        end
      end
    end

    return false if smear_positive_patient == false
    return false if has_no_results == false
    return true
  end

  def previous_sputum_results(registration_date, patient_id)
    sputum_concept_names = ["AAFB(1st) results", "AAFB(2nd) results",
      "AAFB(3rd) results", "Culture(1st) Results", "Culture-2 Results"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)",
        sputum_concept_names]).map(&:concept_id)
    obs = Observation.find(:all,
      :conditions => ["person_id = ? AND concept_id IN (?) AND date_created < ?",
        patient_id, sputum_concept_ids, registration_date],
      :order => "obs_datetime desc", :limit => 3)
  end

  def given_sputum_results(patient_id)
   @given_results = []
    Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("GIVE LAB RESULTS").id,patient_id]).observations.map{|o| @given_results << o.answer_string.to_s.strip if o.to_s.include?("Laboratory results given to patient")} rescue []
  end

  def get_recent_lab_orders_label(patient_id)
    encounters = Encounter.find(:all,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("LAB ORDERS").id,patient_id]).last(5)
      observations = []

    encounters.each{|encounter|
      encounter.observations.each{|observation|
       unless observation['concept_id'] == Concept.find_by_name("Workstation location").concept_id
          observations << ["#{ConceptName.find_by_concept_id(observation['value_coded'].to_i).name} : #{observation['date_created'].strftime("%Y-%m-%d") }",
                            "#{observation['obs_id']}"]
       end
      }
    }
    return observations
  end

  def recent_lab_orders_label(test_list, patient)
  	patient_bean = PatientService.get_patient(patient.person)
    lab_orders = test_list
    labels = []
    i = 0
    lab_orders.each{|test|
      observation = Observation.find(test.to_i)

      accession_number = "#{observation.accession_number rescue nil}"
		patient_national_id_with_dashes = PatientService.get_national_id_with_dashes(patient)
        if accession_number != ""
          label = 'label' + i.to_s
          label = ZebraPrinter::Label.new(500,165)
          label.font_size = 2
          label.font_horizontal_multiplier = 1
          label.font_vertical_multiplier = 1
          label.left_margin = 300
          label.draw_barcode(50,105,0,1,4,8,50,false,"#{accession_number}")
          label.draw_multi_text("#{patient_bean.name.titleize.delete("'")} #{patient_national_id_with_dashes}")
          label.draw_multi_text("#{observation.name rescue nil} - #{accession_number rescue nil}")
          label.draw_multi_text("#{observation.date_created.strftime("%d-%b-%Y %H:%M")}")
          labels << label
         end

         i = i + 1
    }

      print_labels = []
      label = 0
      while label <= labels.size
        print_labels << labels[label].print(1) if labels[label] != nil
        label = label + 1
      end

      return print_labels
  end

  # Get the any BMI-related alert for this patient
  def current_bmi_alert(patient_weight, patient_height)
    weight = patient_weight
    height = patient_height
    alert = nil
    unless weight == 0 || height == 0
      current_bmi = (weight/(height*height)*10000).round(1);
      if current_bmi <= 18.5 && current_bmi > 17.0
        alert = 'Low BMI: Eligible for counseling'
      elsif current_bmi <= 17.0
        alert = 'Low BMI: Eligible for therapeutic feeding'
      end
    end

    alert
  end

  #moved from the patient model. Needs good testing
  def demographics_label(patient_id)
    patient = Patient.find(patient_id)
    patient_bean = PatientService.get_patient(patient.person)
    demographics = mastercard_demographics(patient)
    hiv_staging = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV Staging").id,patient.id])

    tb_within_last_two_yrs = "tb within last 2 yrs" unless demographics.tb_within_last_two_yrs.blank?
    eptb = "eptb" unless demographics.eptb.blank?
    pulmonary_tb = "Pulmonary tb" unless demographics.pulmonary_tb.blank?

    cd4_count_date = nil ; cd4_count = nil ; pregnant = 'N/A'

    (hiv_staging.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'CD4 COUNT DATETIME'
        cd4_count_date = obs.value_datetime.to_date
      when 'CD4 COUNT'
        cd4_count = obs.value_numeric
      when 'IS PATIENT PREGNANT?'
        pregnant = obs.to_s.split(':')[1] rescue nil
      end
    end rescue []

    office_phone_number = PatientService.get_attribute(patient.person, 'Office phone number')
    home_phone_number = PatientService.get_attribute(patient.person, 'Home phone number')
    cell_phone_number = PatientService.get_attribute(patient.person, 'Cell phone number')

    phone_number = office_phone_number if not office_phone_number.downcase == "not available" and not office_phone_number.downcase == "unknown" rescue nil
    phone_number= home_phone_number if not home_phone_number.downcase == "not available" and not home_phone_number.downcase == "unknown" rescue nil
    phone_number = cell_phone_number if not cell_phone_number.downcase == "not available" and not cell_phone_number.downcase == "unknown" rescue nil

    initial_height = PatientService.get_patient_attribute_value(patient, "initial_height")
    initial_weight = PatientService.get_patient_attribute_value(patient, "initial_weight")

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
    label.draw_text("#{demographics.arv_number}",575,30,0,3,1,1,false)
    label.draw_text("PATIENT DETAILS",25,30,0,3,1,1,false)
    label.draw_text("Name:   #{demographics.name} (#{demographics.sex})",25,60,0,3,1,1,false)
    label.draw_text("DOB:    #{PatientService.birthdate_formatted(patient.person)}",25,90,0,3,1,1,false)
    label.draw_text("Phone: #{phone_number}",25,120,0,3,1,1,false)
    if demographics.address.length > 48
      label.draw_text("Addr:  #{demographics.address[0..47]}",25,150,0,3,1,1,false)
      label.draw_text("    :  #{demographics.address[48..-1]}",25,180,0,3,1,1,false)
      last_line = 180
    else
      label.draw_text("Addr:  #{demographics.address}",25,150,0,3,1,1,false)
      last_line = 150
    end

    if !demographics.guardian.nil?
      if last_line == 180 and demographics.guardian.length < 48
        label.draw_text("Guard: #{demographics.guardian}",25,210,0,3,1,1,false)
        last_line = 210
      elsif last_line == 180 and demographics.guardian.length > 48
        label.draw_text("Guard: #{demographics.guardian[0..47]}",25,210,0,3,1,1,false)
        label.draw_text("     : #{demographics.guardian[48..-1]}",25,240,0,3,1,1,false)
        last_line = 240
      elsif last_line == 150 and demographics.guardian.length > 48
        label.draw_text("Guard: #{demographics.guardian[0..47]}",25,180,0,3,1,1,false)
        label.draw_text("     : #{demographics.guardian[48..-1]}",25,210,0,3,1,1,false)
        last_line = 210
      elsif last_line == 150 and demographics.guardian.length < 48
        label.draw_text("Guard: #{demographics.guardian}",25,180,0,3,1,1,false)
        last_line = 180
      end
    else
      if last_line == 180
        label.draw_text("Guard: None",25,210,0,3,1,1,false)
        last_line = 210
      elsif last_line == 180
        label.draw_text("Guard: None}",25,210,0,3,1,1,false)
        last_line = 240
      elsif last_line == 150
        label.draw_text("Guard: None",25,180,0,3,1,1,false)
        last_line = 210
      elsif last_line == 150
        label.draw_text("Guard: None",25,180,0,3,1,1,false)
        last_line = 180
      end
    end

    label.draw_text("TI:    #{demographics.transfer_in ||= 'No'}",25,last_line+=30,0,3,1,1,false)
    label.draw_text("FUP:   (#{demographics.agrees_to_followup})",25,last_line+=30,0,3,1,1,false)


    label2 = ZebraPrinter::StandardLabel.new
    #Vertical lines
=begin
     label2.draw_line(45,40,5,242)
     label2.draw_line(805,40,5,242)
     label2.draw_line(365,40,5,242)
     label2.draw_line(575,40,5,242)

     #horizontal lines
     label2.draw_line(45,40,795,3)
     label2.draw_line(45,80,795,3)
     label2.draw_line(45,120,795,3)
     label2.draw_line(45,200,795,3)
     label2.draw_line(45,240,795,3)
     label2.draw_line(45,280,795,3)
=end
    label2.draw_line(25,170,795,3)
    #label data
    label2.draw_text("STATUS AT ART INITIATION",25,30,0,3,1,1,false)
    label2.draw_text("(DSA:#{patient.date_started_art.strftime('%d-%b-%Y') rescue 'N/A'})",370,30,0,2,1,1,false)
    label2.draw_text("#{demographics.arv_number}",580,20,0,3,1,1,false)
    label2.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",25,300,0,1,1,1,false)

    label2.draw_text("RFS: #{demographics.reason_for_art_eligibility}",25,70,0,2,1,1,false)
    label2.draw_text("#{cd4_count} #{cd4_count_date}",25,110,0,2,1,1,false)
    label2.draw_text("1st + Test: #{demographics.hiv_test_date}",25,150,0,2,1,1,false)

    label2.draw_text("TB: #{tb_within_last_two_yrs} #{eptb} #{pulmonary_tb}",380,70,0,2,1,1,false)
    label2.draw_text("KS:#{demographics.ks rescue nil}",380,110,0,2,1,1,false)
    label2.draw_text("Preg:#{pregnant}",380,150,0,2,1,1,false)
    label2.draw_text("#{demographics.first_line_drugs.join(',')[0..32] rescue nil}",25,190,0,2,1,1,false)
    label2.draw_text("#{demographics.alt_first_line_drugs.join(',')[0..32] rescue nil}",25,230,0,2,1,1,false)
    label2.draw_text("#{demographics.second_line_drugs.join(',')[0..32] rescue nil}",25,270,0,2,1,1,false)

    label2.draw_text("HEIGHT: #{initial_height}",570,70,0,2,1,1,false)
    label2.draw_text("WEIGHT: #{initial_weight}",570,110,0,2,1,1,false)
    label2.draw_text("Init Age: #{PatientService.patient_age_at_initiation(patient, demographics.date_of_first_line_regimen) rescue nil}",570,150,0,2,1,1,false)

    line = 190
    extra_lines = []
    label2.draw_text("STAGE DEFINING CONDITIONS",450,190,0,3,1,1,false)
    (hiv_staging.observations).each{|obs|
      name = obs.to_s.split(':')[0].strip.upcase rescue nil
      condition = obs.to_s.split(':')[1].strip.humanize rescue nil
      next unless name == 'WHO STAGES CRITERIA PRESENT'
      line+=25
      if line <= 290
        label2.draw_text(condition[0..35],450,line,0,1,1,1,false)
      end
      extra_lines << condition[0..79] if line > 290
    } rescue []

    if line > 310 and !extra_lines.blank?
      line = 30
      label3 = ZebraPrinter::StandardLabel.new
      label3.draw_text("STAGE DEFINING CONDITIONS",25,line,0,3,1,1,false)
      label3.draw_text("#{PatientService.get_patient_identifier(patient, 'ARV Number')}",370,line,0,2,1,1,false)
      label3.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
      extra_lines.each{|condition|
        label3.draw_text(condition,25,line+=30,0,2,1,1,false)
      } rescue []
    end
    return "#{label.print(1)} #{label2.print(1)} #{label3.print(1)}" if !extra_lines.blank?
    return "#{label.print(1)} #{label2.print(1)}"
  end

  def patient_transfer_out_label(patient_id)
    patient = Patient.find_by_patient_id(patient_id)
    patient_bean = PatientService.get_patient(patient.person)
    demographics = mastercard_demographics(patient)
    demographics_str = []

		label = ZebraPrinter::Label.new(776, 329, 'T')
    label.line_spacing = 0
    label.top_margin = 30
    label.bottom_margin = 30
    label.left_margin = 25
    label.x = 25
    label.y = 30
    label.font_size = 3
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1

    # 25, 30
    # Patient personanl data
    label.draw_multi_text("#{Location.current_health_center.name} transfer out label", {:font_reverse => true})
    label.draw_multi_text("From #{Location.current_health_center.name} to #{demographics.transferred_out_to}", {:font_reverse => false})
    label.draw_multi_text("ARV number: #{demographics.arv_number}", {:font_reverse => true})
    label.draw_multi_text("Name: #{demographics.name} (#{demographics.sex})\nAge: #{demographics.age}", {:font_reverse => false})

    # Print information on Diagnosis!
    label.draw_multi_text("Diagnosis", {:font_reverse => true})
    label.draw_multi_text("Reason for starting: #{demographics.reason_for_art_eligibility}", {:font_reverse => false})
    label.draw_multi_text("Art start date: #{demographics.art_start_date} ", {:font_reverse => false})
    label.draw_multi_text("HIV test type: #{demographics.first_positive_hiv_test_type} ", {:font_reverse => false})
    label.draw_multi_text("Other diagnosis:", {:font_reverse => true})

# !!!! TODO
		initial_staging_conditions = Encounter.find(:first,:conditions =>["encounter_type = ? and patient_id = ?",
          EncounterType.find_by_name("HIV STAGING").encounter_type_id,patient_id]) rescue nil

    staging_observations = initial_staging_conditions.observations.collect{|obs| obs.to_s if obs.value_coded == Concept.find_by_name("Yes").id}.compact rescue []

		staging_conditions = ""
    count = 1
    staging_observations.each{|condition|
     staging_conditions+= " (#{count+=1}) " unless staging_conditions.blank?
     staging_conditions= "(#{count}) " if staging_conditions.blank?
     staging_conditions+=condition
    }
    label.draw_multi_text("#{staging_conditions}", {:font_reverse => false})

		# Print information on current status of the patient transfering out!
    work = demographics.occupation rescue nil
    #amb = self.observations.find_last_by_concept_name("Is able to walk unaided").to_short_s rescue nil

    first_cd4_count = Observation.find(:first, :conditions => ["concept_id = ? and person_id = ?", ConceptName.find_by_name("CD4 count").concept_id, patient_bean.person_id])
    
    last_cd4_count = Observation.find(:last, :conditions => ["concept_id = ? and person_id = ?", ConceptName.find_by_name("CD4 count").concept_id, patient_bean.person_id])
    
    last_cd4 = "Last CD4: " + last_cd4_count.obs_datetime.strftime("%d-%b-%Y") + ": " + last_cd4_count.to_s rescue nil
    first_cd4 = "First CD4: " + first_cd4_count.obs_datetime.strftime("%d-%b-%Y") + ": " + first_cd4_count.to_s rescue nil

		label.draw_multi_text("Current Status", {:font_reverse => true})
    label.draw_multi_text("Occupation: #{work}", {:font_reverse => false})
    label.draw_multi_text("#{first_cd4}", {:font_reverse => false})
    label.draw_multi_text("#{last_cd4}", {:font_reverse => false})

		last_dispensing_encounter_date = Encounter.find(:last, :conditions => ['encounter_type = ? AND patient_id = ?', EncounterType.find_by_name("DISPENSING").encounter_type_id, patient_id]).encounter_datetime rescue Date.today

		# Print information on current treatment of the patient transfering out!
    current_drugs = PatientService.drugs_given_on(patient, last_dispensing_encounter_date.to_date)
    current_art_drugs = current_drugs.collect{|drug_name_quantity|drug_name_quantity.to_s} rescue nil
    current_art_drugs = current_art_drugs.collect{|drug_name|drug_name.split(":")[0]} rescue nil

    drug_names = ""
    count = 1
    current_art_drugs.each{|name|
     drug_names+= " (#{count+=1}) " unless drug_names.blank?
     drug_names= "(#{count}) " if drug_names.blank?
     drug_names+=name
    } rescue nil

		start_date = self.date_started_art.strftime("%d-%b-%Y") rescue nil
    label.draw_multi_text("Current art drugs", {:font_reverse => true})
    label.draw_multi_text("#{drug_names}", {:font_reverse => false})
    label.draw_multi_text("Transfer out date:", {:font_reverse => true})
    label.draw_multi_text("#{demographics.transferred_out_date}", {:font_reverse => false})

    return label.print(1)

=begin
    #this is the part that prints a 2D barcode
    demographics_str << "Name: #{demographics.name}"
    demographics_str << "DOB: #{patient_bean.birth_date}"
    demographics_str << "DOB-E: #{patient_bean.birthdate_estimated}"
    demographics_str << "Sex: #{demographics.sex}"
    demographics_str << "Guardian name: #{demographics.guardian}"
    demographics_str << "ARV number: #{demographics.arv_number}"
    demographics_str << "National ID: #{demographics.national_id}"

    demographics_str << "Address: #{demographics.address}"
    demographics_str << "FU: #{demographics.agrees_to_followup}"
    demographics_str << "1st alt line: #{demographics.alt_first_line_drugs.join(':')}"
    demographics_str << "BMI: #{demographics.bmi}"
    demographics_str << "CD4: #{demographics.cd4_count}"
    demographics_str << "CD4 date: #{demographics.cd4_count_date}"
    demographics_str << "1st line date: #{demographics.date_of_first_line_regimen}"
    demographics_str << "ERA: #{demographics.ever_received_art}"
    demographics_str << "1st line: #{demographics.first_line_drugs.join(':')}"
    demographics_str << "1st pos HIV test date: #{demographics.first_positive_hiv_test_date}"

    demographics_str << "1st pos HIV test site: #{demographics.first_positive_hiv_test_site}"
    demographics_str << "1st pos HIV test type: #{demographics.first_positive_hiv_test_type}"
    demographics_str << "Test date: #{demographics.hiv_test_date.gsub('/','-')}" if demographics.hiv_test_date
    demographics_str << "Test loc: #{demographics.hiv_test_location}"
    demographics_str << "Init HT: #{demographics.init_ht}"
    demographics_str << "Init WT: #{demographics.init_wt}"
    demographics_str << "Landmark: #{demographics.landmark}"
    demographics_str << "Occupation: #{demographics.occupation}"
    demographics_str << "Preg: #{demographics.pregnant}" if patient.person.gender == 'F'
    demographics_str << "SR: #{demographics.reason_for_art_eligibility}"
    demographics_str << "2nd line: #{demographics.second_line_drugs}"
    demographics_str << "TB status: #{demographics.tb_status_at_initiation}"
    demographics_str << "TI: #{demographics.transfer_in}"
    demographics_str << "TI date: #{demographics.transfer_in_date}"


    visits = visits(patient) ; count = 0 ; visit_str = nil
    (visits || {}).sort{|a,b| b[0].to_date<=>a[0].to_date}.each do | date,visit |
      break if count > 3
      visit_str = "Visit date: #{date}" if visit_str.blank?
      visit_str += ";Visit date: #{date}" unless visit_str.blank?
      visit_str += ";wt: #{visit.weight}" if visit.weight
      visit_str += ";ht: #{visit.height}" if visit.height
      visit_str += ";bmi: #{visit.bmi}" if visit.bmi
      visit_str += ";Outcome: #{visit.outcome}" if visit.outcome
      visit_str += ";Regimen: #{visit.reg}" if visit.reg
      visit_str += ";Adh: #{visit.adherence.join(' ')}" if visit.adherence
      visit_str += ";TB status: #{visit.tb_status}" if visit.tb_status
      gave = nil
      (visit.gave.uniq || []).each do | name , quantity |
        gave += "  #{name} (#{quantity})" unless gave.blank?
        gave = ";Gave: #{name} (#{quantity})" if gave.blank?
      end rescue []
      visit_str += gave unless gave.blank?
      count+=1
      demographics_str << visit_str
    end

    label = ZebraPrinter::StandardLabel.new
    label.draw_2D_barcode(80,20,'P',700,600,'x2','y7','l100','r100','f0','s5',"#{demographics_str.join(',').gsub('/','')}")
    label.print(1)
=end
  end

  def patient_lab_orders_label(patient_id)
    patient = Patient.find(patient_id)
    patient_bean = PatientService.get_patient(patient.person)
    
    lab_orders = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("LAB ORDERS").id,patient.id]).observations
      labels = []
      i = 0
      
      while i <= lab_orders.size do
        accession_number = "#{lab_orders[i].accession_number rescue nil}"
		patient_national_id_with_dashes = PatientService.get_national_id_with_dashes(patient)
        if accession_number != ""
          label = 'label' + i.to_s
          label = ZebraPrinter::Label.new(500,165)
          label.font_size = 2
          label.font_horizontal_multiplier = 1
          label.font_vertical_multiplier = 1
          label.left_margin = 300
          label.draw_barcode(50,105,0,1,4,8,50,false,"#{accession_number}")
          label.draw_multi_text("#{patient_bean.name.titleize.delete("'")} #{patient_national_id_with_dashes}")
          label.draw_multi_text("#{lab_orders[i].name rescue nil} - #{accession_number rescue nil}")
          label.draw_multi_text("#{lab_orders[i].obs_datetime.strftime("%d-%b-%Y %H:%M")}")
          labels << label
          end
          i = i + 1
      end

      print_labels = []
      label = 0
      while label <= labels.size
        print_labels << labels[label].print(2) if labels[label] != nil
        label = label + 1
      end

      return print_labels
  end

  def patient_filing_number_label(patient, num = 1)
    file = PatientService.get_patient_identifier(patient, 'Filing Number')[0..9]
    file_type = file.strip[3..4]
    version_number=file.strip[2..2]
    number = file
    len = number.length - 5
    number = number[len..len] + "   " + number[(len + 1)..(len + 2)]  + " " +  number[(len + 3)..(number.length)]

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("#{number}",75, 30, 0, 4, 4, 4, false)
    label.draw_text("Filing area #{file_type}",75, 150, 0, 2, 2, 2, false)
    label.draw_text("Version number: #{version_number}",75, 200, 0, 2, 2, 2, false)
    label.print(num)
  end

  def patient_visit_label(patient, date = Date.today)
    result = Location.find(session[:location_id]).name.match(/outpatient/i)

    unless result
      return mastercard_visit_label(patient,date)
    else
      label = ZebraPrinter::StandardLabel.new
      label.font_size = 3
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1
      label.left_margin = 50
      encs = patient.encounters.find(:all,:conditions =>["DATE(encounter_datetime) = ?",date])
      return nil if encs.blank?

      label.draw_multi_text("Visit: #{encs.first.encounter_datetime.strftime("%d/%b/%Y %H:%M")}", :font_reverse => true)
      encs.each {|encounter|
        next if encounter.name.upcase == "REGISTRATION"
        next if encounter.name.upcase == "HIV REGISTRATION"
        next if encounter.name.upcase == "HIV STAGING"
        next if encounter.name.upcase == "HIV CLINIC CONSULTATION"
        next if encounter.name.upcase == "VITALS"
        next if encounter.name.upcase == "ART ADHERENCE"
        encounter.to_s.split("<b>").each do |string|
          concept_name = string.split("</b>:")[0].strip rescue nil
          obs_value = string.split("</b>:")[1].strip rescue nil
          next if string.match(/Workstation location/i)
          next if obs_value.blank?
          label.draw_multi_text("#{encounter.name.humanize} - #{concept_name}: #{obs_value}", :font_reverse => false)
        end
      }
      label.print(1)
    end
  end

  def mastercard_demographics(patient_obj)
  	patient_bean = PatientService.get_patient(patient_obj.person)
    visits = Mastercard.new()
    visits.patient_id = patient_obj.id
    visits.arv_number = patient_bean.arv_number
    visits.address = patient_bean.address
    visits.national_id = patient_bean.national_id
    visits.name = patient_bean.name rescue nil
    visits.sex = patient_bean.sex
    visits.age = patient_bean.age
    visits.occupation = PatientService.get_attribute(patient_obj.person, 'Occupation')
    visits.landmark = patient_obj.person.addresses.first.address1
    visits.init_wt = PatientService.get_patient_attribute_value(patient_obj, "initial_weight")
    visits.init_ht = PatientService.get_patient_attribute_value(patient_obj, "initial_height")
    visits.bmi = PatientService.get_patient_attribute_value(patient_obj, "initial_bmi")
    visits.agrees_to_followup = patient_obj.person.observations.recent(1).question("Agrees to followup").all rescue nil
    visits.agrees_to_followup = visits.agrees_to_followup.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_date = patient_obj.person.observations.recent(1).question("Confirmatory HIV test date").all rescue nil
    visits.hiv_test_date = visits.hiv_test_date.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_location = patient_obj.person.observations.recent(1).question("Confirmatory HIV test location").all rescue nil
    location_name = Location.find_by_location_id(visits.hiv_test_location.to_s.split(':')[1].strip).name rescue nil
    visits.hiv_test_location = location_name rescue nil
    visits.guardian = art_guardian(patient_obj) rescue nil
    visits.reason_for_art_eligibility = PatientService.reason_for_art_eligibility(patient_obj)
    visits.transfer_in = PatientService.is_transfer_in(patient_obj) rescue nil #pb: bug-2677 Made this to use the newly created patient model method 'transfer_in?'
    visits.transfer_in == false ? visits.transfer_in = 'NO' : visits.transfer_in = 'YES'

    transferred_out_details = Observation.find(:last, :conditions =>["concept_id = ? and person_id = ?",
        ConceptName.find_by_name("TRANSFER OUT TO").concept_id,patient_bean.patient_id]) rescue ""

		visits.transferred_out_to = transferred_out_details.value_text if transferred_out_details 
		visits.transferred_out_date = transferred_out_details.obs_datetime if transferred_out_details

		visits.art_start_date = PatientService.patient_art_start_date(patient_bean.patient_id).strftime("%d-%B-%Y")

    visits.transfer_in_date = patient_obj.person.observations.recent(1).question("HAS TRANSFER LETTER").all.collect{|o|
            o.obs_datetime if o.answer_string.strip == "YES"}.last rescue nil

    regimens = {}
    regimen_types = ['FIRST LINE ANTIRETROVIRAL REGIMEN','ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN','SECOND LINE ANTIRETROVIRAL REGIMEN']
    regimen_types.map do | regimen |
      concept_member_ids = ConceptName.find_by_name(regimen).concept.concept_members.collect{|c|c.concept_id}
      case regimen
        when 'FIRST LINE ANTIRETROVIRAL REGIMEN'
          regimens[regimen] = concept_member_ids
        when 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN'
          regimens[regimen] = concept_member_ids
        when 'SECOND LINE ANTIRETROVIRAL REGIMEN'
          regimens[regimen] = concept_member_ids
      end
    end

    first_treatment_encounters = []
    encounter_type = EncounterType.find_by_name('DISPENSING').id
    amount_dispensed_concept_id = ConceptName.find_by_name('Amount dispensed').concept_id
    regimens.map do | regimen_type , ids |
      encounter = Encounter.find(:first,
                                 :joins => "INNER JOIN obs ON encounter.encounter_id = obs.encounter_id",
                                 :conditions =>["encounter_type=? AND encounter.patient_id = ? AND concept_id = ?
                                 AND encounter.voided = 0",encounter_type , patient_obj.id , amount_dispensed_concept_id ],
                                 :order =>"encounter_datetime")
      first_treatment_encounters << encounter unless encounter.blank?
    end

    visits.first_line_drugs = []
    visits.alt_first_line_drugs = []
    visits.second_line_drugs = []

    first_treatment_encounters.map do | treatment_encounter |
      treatment_encounter.observations.map{|obs|
        next if not obs.concept_id == amount_dispensed_concept_id
        drug = Drug.find(obs.value_drug) if obs.value_numeric > 0
		next if obs.value_numeric <= 0
        drug_concept_id = drug.concept.concept_id
        regimens.map do | regimen_type , concept_ids |
          if regimen_type == 'FIRST LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_first_line_regimen = treatment_encounter.encounter_datetime.to_date
            visits.first_line_drugs << drug.concept.shortname
            visits.first_line_drugs = visits.first_line_drugs.uniq rescue []
          elsif regimen_type == 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_first_alt_line_regimen = treatment_encounter.encounter_datetime.to_date
            visits.alt_first_line_drugs << drug.concept.shortname
            visits.alt_first_line_drugs = visits.alt_first_line_drugs.uniq rescue []
          elsif regimen_type == 'SECOND LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_second_line_regimen = treatment_encounter.encounter_datetime.to_date
            visits.second_line_drugs << drug.concept.shortname
            visits.second_line_drugs = visits.second_line_drugs.uniq rescue []
          end
        end
      }.compact
    end

    ans = ["Extrapulmonary tuberculosis (EPTB)","Pulmonary tuberculosis within the last 2 years","Pulmonary tuberculosis","Kaposis sarcoma"]
    staging_ans = patient_obj.person.observations.recent(1).question("WHO STG CRIT").all

    visits.ks = 'Yes' if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[3])
    visits.tb_within_last_two_yrs = 'Yes' if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[1])
    visits.eptb = 'Yes' if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[0])
    visits.pulmonary_tb = 'Yes' if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[2])

    hiv_staging = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV Staging").id,patient_obj.id])

    visits.who_clinical_conditions = ""

    (hiv_staging.observations).collect do |obs|
      name = obs.to_s.split(':')[0].strip rescue nil
      next unless name == 'WHO STAGES CRITERIA PRESENT'
      condition = obs.to_s.split(':')[1].strip.humanize rescue nil
      visits.who_clinical_conditions = visits.who_clinical_conditions + (condition) + "; "
    end rescue []

    # cd4_count_date cd4_count pregnant who_clinical_conditions

    visits.cd4_count_date = nil ; visits.cd4_count = nil ; visits.pregnant = 'N/A'

    (hiv_staging.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'Cd4 count datetime'
        visits.cd4_count_date = obs.value_datetime.to_date
      when 'CD4 count'
        visits.cd4_count = obs.value_numeric.to_i
      when 'IS PATIENT PREGNANT?'
        visits.pregnant = obs.to_s.split(':')[1] rescue nil
      when 'LYMPHOCYTE COUNT'
        visits.tlc = obs.answer_string
      when 'LYMPHOCYTE COUNT DATETIME'
        visits.tlc_date = obs.value_datetime.to_date
      end
    end rescue []
    visits.tb_status_at_initiation = (!visits.tb_status.nil? ? "Curr" :
          (!visits.tb_within_last_two_yrs.nil? ? (visits.tb_within_last_two_yrs.upcase == "YES" ? 
              "Last 2yrs" : "Never/ >2yrs") : "Never/ >2yrs"))

    hiv_clinic_registration = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV CLINIC REGISTRATION").id,patient_obj.id])

    (hiv_clinic_registration.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'Ever received ART?'
        visits.ever_received_art = obs.to_s.split(':')[1].strip rescue nil
      when 'Last ART drugs taken'
        visits.last_art_drugs_taken = obs.to_s.split(':')[1].strip rescue nil
      when 'Date ART last taken'
        visits.last_art_drugs_date_taken = obs.value_datetime.to_date rescue nil
      when 'Confirmatory HIV test location'
        visits.first_positive_hiv_test_site = obs.to_s.split(':')[1].strip rescue nil
      when 'ART number at previous location'
        visits.first_positive_hiv_test_arv_number = obs.to_s.split(':')[1].strip rescue nil
      when 'Confirmatory HIV test type'
        visits.first_positive_hiv_test_type = obs.to_s.split(':')[1].strip rescue nil
      when 'Confirmatory HIV test date'
        visits.first_positive_hiv_test_date = obs.value_datetime.to_date rescue nil
      end
    end rescue []

    visits
  end

  def visits(patient_obj,encounter_date = nil)
    patient_visits = {}
    yes = ConceptName.find_by_name("YES")
    if encounter_date.blank?
      observations = Observation.find(:all,:conditions =>["voided = 0 AND person_id = ?",patient_obj.patient_id],:order =>"obs_datetime").map{|obs| obs if !obs.concept.nil?}
    else
      observations = Observation.find(:all,
        :conditions =>["voided = 0 AND person_id = ? AND Date(obs_datetime) = ?",
        patient_obj.patient_id,encounter_date.to_date],:order =>"obs_datetime").map{|obs| obs if !obs.concept.nil?}
    end

    clinic_encounters = ["APPOINTMENT", "HEIGHT","WEIGHT","REGIMEN","TB STATUS","SYMPTOMS",
      "VISIT","BMI","PILLS BROUGHT",'ADHERENCE','NOTES','DRUGS GIVEN']
    clinic_encounters.map do |field|
      gave_hash = Hash.new(0) 
      observations.map do |obs|
         encounter_name = obs.encounter.name rescue []
         next if encounter_name.blank?
         next if encounter_name.match(/REGISTRATION/i)
         next if encounter_name.match(/HIV STAGING/i)
         visit_date = obs.obs_datetime.to_date
         patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?
         case field
          when 'APPOINTMENT'
            concept_name = obs.concept.fullname
            next unless concept_name.upcase == 'APPOINTMENT DATE' 
            patient_visits[visit_date].appointment_date = obs.value_datetime
          when 'HEIGHT'
            concept_name = obs.concept.fullname rescue nil
            next unless concept_name.upcase == 'HEIGHT (CM)' 
            patient_visits[visit_date].height = obs.answer_string
          when "WEIGHT"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'WEIGHT (KG)' 
            patient_visits[visit_date].weight = obs.answer_string
          when "BMI"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'BODY MASS INDEX, MEASURED' 
            patient_visits[visit_date].bmi = obs.answer_string
          when "VISIT"
            concept_name = obs.concept.fullname.upcase rescue []
            next unless concept_name == 'RESPONSIBLE PERSON PRESENT' or concept_name == 'PATIENT PRESENT FOR CONSULTATION'
            patient_visits[visit_date].visit_by = '' if patient_visits[visit_date].visit_by.blank?
            patient_visits[visit_date].visit_by+= "P" if obs.to_s.squish.match(/Patient present for consultation: Yes/i)
            patient_visits[visit_date].visit_by+= "G" if obs.to_s.squish.match(/Responsible person present: Yes/i)
          when "TB STATUS"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'TB STATUS' 
            status = ConceptName.find(obs.value_coded_name_id).name.upcase rescue nil
            patient_visits[visit_date].tb_status = status
            patient_visits[visit_date].tb_status = 'noSup' if status == 'TB NOT SUSPECTED'
            patient_visits[visit_date].tb_status = 'sup' if status == 'TB SUSPECTED'
            patient_visits[visit_date].tb_status = 'noRx' if status == 'CONFIRMED TB NOT ON TREATMENT'
            patient_visits[visit_date].tb_status = 'Rx' if status == 'CONFIRMED TB ON TREATMENT'
          when "DRUGS GIVEN"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'AMOUNT DISPENSED' 
            drug = Drug.find(obs.value_drug) rescue nil
            next if drug.blank?
            drug_name = drug.concept.shortname rescue drug.name
            if drug_name.match(/Cotrimoxazole/i)
              patient_visits[visit_date].cpt += obs.value_numeric unless patient_visits[visit_date].cpt.blank?
              patient_visits[visit_date].cpt = obs.value_numeric if patient_visits[visit_date].cpt.blank?
            else
              patient_visits[visit_date].gave = [] if patient_visits[visit_date].gave.blank?
              patient_visits[visit_date].gave << [drug_name,obs.value_numeric]
              drugs_given_uniq = Hash.new(0)
              (patient_visits[visit_date].gave || {}).each do |drug_given_name,quantity_given|
                drugs_given_uniq[drug_given_name] += quantity_given
              end
              patient_visits[visit_date].gave = []
              (drugs_given_uniq || {}).each do |drug_given_name,quantity_given|
                patient_visits[visit_date].gave << [drug_given_name,quantity_given]
              end
            end
          when "REGIMEN"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'WHAT TYPE OF ANTIRETROVIRAL REGIMEN' 
            patient_visits[visit_date].reg =  Concept.find_by_concept_id(obs.value_coded).concept_names.typed("SHORT").first.name
          when "SYMPTOMS"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'SYMPTOM PRESENT' 
            symptoms = obs.to_s.split(':').map do | sy |
              sy.sub(concept_name,'').strip.capitalize 
            end rescue []
            patient_visits[visit_date].s_eff = symptoms.join("<br/>") unless symptoms.blank?
          when "PILLS BROUGHT"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'AMOUNT OF DRUG BROUGHT TO CLINIC' 
            drug = Drug.find(obs.order.drug_order.drug_inventory_id) rescue nil
            next if drug.blank?
            drug_name = drug.concept.shortname rescue drug.name
            patient_visits[visit_date].pills = [] if patient_visits[visit_date].pills.blank?
            patient_visits[visit_date].pills << [drug_name,obs.value_numeric] rescue []
          when "ADHERENCE"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER' 
            next if obs.value_numeric.blank?
            patient_visits[visit_date].adherence = [] if patient_visits[visit_date].adherence.blank?
            patient_visits[visit_date].adherence << [Drug.find(obs.order.drug_order.drug_inventory_id).name,(obs.value_numeric.to_s + '%')]
          when "NOTES"
            concept_name = obs.concept.fullname.strip rescue []
            next unless concept_name == 'CLINICAL NOTES CONSTRUCT' || concept_name == 'Clinical notes construct'
            patient_visits[visit_date].notes+= '<br/>' + obs.value_text unless patient_visits[visit_date].notes.blank?
            patient_visits[visit_date].notes = obs.value_text if patient_visits[visit_date].notes.blank?
         end
      end
    end

    #patients currents/available states (patients outcome/s)
    program_id = Program.find_by_name('HIV PROGRAM').id
    if encounter_date.blank?
      patient_states = PatientState.find(:all,
                                    :joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
                                    :conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND p.patient_id = ?",
                                    program_id,patient_obj.patient_id],:order => "patient_state_id ASC")
    else
      patient_states = PatientState.find(:all,
                                    :joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
                                    :conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND start_date = ? AND p.patient_id =?",
                                    program_id,encounter_date.to_date,patient_obj.patient_id],:order => "patient_state_id ASC")  
    end  

=begin
    patient_states.each do |state| 
      visit_date = state.start_date.to_date rescue nil
      next if visit_date.blank?
      patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?
      patient_visits[visit_date].outcome = state.program_workflow_state.concept.fullname rescue 'Unknown state'
      patient_visits[visit_date].date_of_outcome = state.start_date
    end
=end

    patient_visits.each do |visit_date,data| 
      next if visit_date.blank?
      patient_visits[visit_date].outcome = latest_state(patient_obj,visit_date)
      patient_visits[visit_date].date_of_outcome = visit_date
    end

    unless encounter_date.blank? 
      outcome = patient_visits[encounter_date].outcome rescue nil
      if outcome.blank?
        state = PatientState.find(:first,
                                  :joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
                                  :conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND p.patient_id = ?",
                                  program_id,patient_obj.patient_id],:order => "date_enrolled DESC,start_date DESC")

        patient_visits[encounter_date] = Mastercard.new() if patient_visits[encounter_date].blank?
        patient_visits[encounter_date].outcome = state.program_workflow_state.concept.fullname rescue 'Unknown state'
        patient_visits[encounter_date].date_of_outcome = state.start_date rescue nil
      end
    end

    patient_visits
  end  

  def mastercard_visit_label(patient,date = Date.today)
  	patient_bean = PatientService.get_patient(patient.person)
    visit = visits(patient,date)[date] rescue {}

    return if visit.blank? 
    visit_data = mastercard_visit_data(visit)
    arv_number = patient_bean.arv_number || patient_bean.national_id
    pill_count = visit.pills.collect{|c|c.join(",")}.join(' ') rescue nil

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
    label.draw_text("#{seen_by(patient,date)}",597,250,0,1,1,1,false)
    label.draw_text("#{date.strftime("%B %d %Y").upcase}",25,30,0,3,1,1,false)
    label.draw_text("#{arv_number}",565,30,0,3,1,1,true)
    label.draw_text("#{patient_bean.name}(#{patient_bean.sex})",25,60,0,3,1,1,false)
    label.draw_text("#{'(' + visit.visit_by + ')' unless visit.visit_by.blank?}",255,30,0,2,1,1,false)
    label.draw_text("#{visit.height.to_s + 'cm' if !visit.height.blank?}  #{visit.weight.to_s + 'kg' if !visit.weight.blank?}  #{'BMI:' + visit.bmi.to_s if !visit.bmi.blank?} #{'(PC:' + pill_count[0..24] + ')' unless pill_count.blank?}",25,95,0,2,1,1,false)
    label.draw_text("SE",25,130,0,3,1,1,false)
    label.draw_text("TB",110,130,0,3,1,1,false)
    label.draw_text("Adh",185,130,0,3,1,1,false)
    label.draw_text("DRUG(S) GIVEN",255,130,0,3,1,1,false)
    label.draw_text("OUTC",577,130,0,3,1,1,false)
    label.draw_line(25,150,800,5)
    label.draw_text("#{visit.tb_status}",110,160,0,2,1,1,false)
    label.draw_text("#{adherence_to_show(visit.adherence).gsub('%', '\\\\%') rescue nil}",185,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome']}",577,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome_date']}",655,130,0,2,1,1,false)
    starting_index = 25
    start_line = 160

    visit_data.each{|key,values|
      data = values.last rescue nil
      next if data.blank?
      bold = false
      #bold = true if key.include?("side_eff") and data !="None"
      #bold = true if key.include?("arv_given") 
      starting_index = values.first.to_i
      starting_line = start_line 
      starting_line = start_line + 30 if key.include?("2")
      starting_line = start_line + 60 if key.include?("3")
      starting_line = start_line + 90 if key.include?("4")
      starting_line = start_line + 120 if key.include?("5")
      starting_line = start_line + 150 if key.include?("6")
      starting_line = start_line + 180 if key.include?("7")
      starting_line = start_line + 210 if key.include?("8")
      starting_line = start_line + 240 if key.include?("9")
      next if starting_index == 0
      label.draw_text("#{data}",starting_index,starting_line,0,2,1,1,bold)
    } rescue []
    label.print(2)
  end

  def adherence_to_show(adherence_data)
    #For now we will only show the adherence of the drug with the lowest/highest adherence %
    #i.e if a drug adherence is showing 86% and their is another drug with an adherence of 198%,then 
    #we will show the one with 198%.
    #in future we are planning to show all available drug adherences

    adherence_to_show = 0
    adherence_over_100 = 0
    adherence_below_100 = 0
    over_100_done = false
    below_100_done = false

    adherence_data.each{|drug,adh|
      next if adh.blank?
      drug_adherence = adh.to_i
      if drug_adherence <= 100
        adherence_below_100 = adh.to_i if adherence_below_100 == 0
        adherence_below_100 = adh.to_i if drug_adherence <= adherence_below_100
        below_100_done = true
      else
        adherence_over_100 = adh.to_i if adherence_over_100 == 0
        adherence_over_100 = adh.to_i if drug_adherence >= adherence_over_100
        over_100_done = true
      end

    }

    return if !over_100_done and !below_100_done
    over_100 = 0
    below_100 = 0
    over_100 = adherence_over_100 - 100 if over_100_done
    below_100 = 100 - adherence_below_100 if below_100_done

    return "#{adherence_over_100}%" if over_100 >= below_100 and over_100_done
    return "#{adherence_below_100}%"
  end

  def mastercard_visit_data(visit)
    return if visit.blank?
    data = {}
    data["outcome"] = visit.outcome rescue nil
    if visit.appointment_date and (data["outcome"].match(/ON ANTIRETROVIRALS/i) || data["outcome"].match(/Pre-ART/i) || data["outcome"].blank?)
      data["outcome"] = "Next: #{visit.appointment_date.strftime('%b %d %Y')}" 
    else
      data["outcome_date"] = "#{visit.date_of_outcome.to_date.strftime('%b %d %Y')}" if visit.date_of_outcome
    end

    count = 1
    (visit.s_eff.split("<br/>").compact.reject(&:blank?) || []).each do |side_eff|
      data["side_eff#{count}"] = "25",side_eff[0..5]
      count+=1
    end if visit.s_eff

    count = 1
    (visit.gave || []).each do | drug, pills |
      string = "#{drug} (#{pills})"
      if string.length > 26
        line = string[0..25]
        line2 = string[26..-1] 
        data["arv_given#{count}"] = "255",line
        data["arv_given#{count+=1}"] = "255",line2
      else
        data["arv_given#{count}"] = "255",string
      end
      count+= 1
    end rescue []

    unless visit.cpt.blank?
      data["arv_given#{count}"] = "255","CPT (#{visit.cpt})" unless visit.cpt == 0
    end rescue []

    data
  end
  
  def seen_by(patient,date = Date.today)
    provider = patient.encounters.find_by_date(date).collect{|e| next unless e.name == 'HIV CLINIC CONSULTATION' ; [e.name,e.creator]}.compact 
    provider_username = "#{'Seen by: ' + User.find(provider[0].last).username}" unless provider.blank?
    if provider_username.blank? 
      clinic_encounters = ["HIV CLINIC CONSULTATION","HIV STAGING","ART ADHERENCE","TREATMENT",'DISPENSION','HIV RECEPTION']
      encounter_type_ids = EncounterType.find(:all,:conditions =>["name IN (?)",clinic_encounters]).collect{| e | e.id }
      encounter = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type In (?)",
                  patient.id,encounter_type_ids],:order => "encounter_datetime DESC")
      provider_username = "#{'Recorded by: ' + User.find(encounter.creator).username}" rescue nil
    end
    provider_username
  end

  def art_guardian(patient)
    person_id = Relationship.find(:first,:order => "date_created DESC",
      :conditions =>["person_a = ?",patient.person.id]).person_b rescue nil
    patient_bean = PatientService.get_patient(Person.find(person_id))
    patient_bean.name rescue nil
  end

  def save_mastercard_attribute(params)
    patient = Patient.find(params[:patient_id])
    case params[:field]
    when 'arv_number'
      type = params['identifiers'][0][:identifier_type]
      #patient = Patient.find(params[:patient_id])
      patient_identifiers = PatientIdentifier.find(:all,
        :conditions => ["voided = 0 AND identifier_type = ? AND patient_id = ?",type.to_i,patient.id])

      patient_identifiers.map{|identifier|
        identifier.voided = 1
        identifier.void_reason = "given another number"
        identifier.date_voided  = Time.now()
        identifier.voided_by = current_user.id
        identifier.save
      }

      identifier = params['identifiers'][0][:identifier].strip
      if identifier.match(/(.*)[A-Z]/i).blank?
        params['identifiers'][0][:identifier] = "#{PatientIdentifier.site_prefix}-ARV-#{identifier}"
      end
      patient.patient_identifiers.create(params[:identifiers])
    when "name"
      names_params =  {"given_name" => params[:given_name].to_s,"family_name" => params[:family_name].to_s}
      patient.person.names.first.update_attributes(names_params) if names_params
    when "age"
      birthday_params = params[:person]

      if !birthday_params.empty?
        if birthday_params["birth_year"] == "Unknown"
          PatientService.set_birthdate_by_age(patient.person, birthday_params["age_estimate"])
        else
          PatientService.set_birthdate(patient.person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
        end
        patient.person.birthdate_estimated = 1 if params["birthdate_estimated"] == 'true'
        patient.person.save
      end
    when "sex"
      gender ={"gender" => params[:gender].to_s}
      patient.person.update_attributes(gender) if !gender.empty?
    when "location"
      location = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(location) if location
    when "occupation"
      attribute = params[:person][:attributes]
      occupation_attribute = PersonAttributeType.find_by_name("Occupation")
      exists_person_attribute = PersonAttribute.find(:first, :conditions => ["person_id = ? AND person_attribute_type_id = ?", patient.person.id, occupation_attribute.person_attribute_type_id]) rescue nil
      if exists_person_attribute
        exists_person_attribute.update_attributes({'value' => attribute[:occupation].to_s})
      end
    when "guardian"
      names_params =  {"given_name" => params[:given_name].to_s,"family_name" => params[:family_name].to_s}
      Person.find(params[:guardian_id].to_s).names.first.update_attributes(names_params) rescue '' if names_params
    when "address"
      address2 = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(address2) if address2
    when "ta"
      county_district = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(county_district) if county_district
    when "cell_phone_number"
      attribute_type = PersonAttributeType.find_by_name("Cell Phone Number").id
      person_attribute = patient.person.person_attributes.find_by_person_attribute_type_id(attribute_type)
      if person_attribute.blank?
        attribute = {'value' => params[:person]["cell_phone_number"],
                     'person_attribute_type_id' => attribute_type,
                     'person_id' => patient.id}
        PersonAttribute.create(attribute)
      else
        person_attribute.update_attributes({'value' => params[:person]["cell_phone_number"]})
      end
    when "office_phone_number"
      attribute_type = PersonAttributeType.find_by_name("Office Phone Number").id
      person_attribute = patient.person.person_attributes.find_by_person_attribute_type_id(attribute_type)
      if person_attribute.blank?
        attribute = {'value' => params[:person]["office_phone_number"],
                     'person_attribute_type_id' => attribute_type,
                     'person_id' => patient.id}
        PersonAttribute.create(attribute)
      else
        person_attribute.update_attributes({'value' => params[:person]["office_phone_number"]})
      end
    when "home_phone_number"
      attribute_type = PersonAttributeType.find_by_name("Home Phone Number").id
      person_attribute = patient.person.person_attributes.find_by_person_attribute_type_id(attribute_type)
      if person_attribute.blank?
        attribute = {'value' => params[:person]["home_phone_number"],
                     'person_attribute_type_id' => attribute_type,
                     'person_id' => patient.id}
        PersonAttribute.create(attribute)
      else
        person_attribute.update_attributes({'value' => params[:person]["home_phone_number"]})
      end
    end
  end

  def edit_mastercard_attribute(attribute_name)
    edit_page = attribute_name
  end

  def set_new_patient_filing_number(patient)
    ActiveRecord::Base.transaction do
      global_property_value = GlobalProperty.find_by_property("filing.number.limit").property_value rescue '10'

      filing_number_identifier_type = PatientIdentifierType.find_by_name("Filing number")
      archive_identifier_type = PatientIdentifierType.find_by_name("Archived filing number")

      next_filing_number = PatientIdentifier.next_filing_number('Filing number')
      if (next_filing_number[5..-1].to_i >= global_property_value.to_i)
        encounter_type_name = ['REGISTRATION','VITALS','HIV CLINIC REGISTRATION','HIV CLINIC CONSULTATION',
          'TREATMENT','HIV RECEPTION','HIV STAGING','DISPENSING','APPOINTMENT']
        encounter_type_ids = EncounterType.find(:all,:conditions => ["name IN (?)",encounter_type_name]).map{|n|n.id}

        all_filing_numbers = PatientIdentifier.find(:all, :conditions =>["identifier_type = ?",
            filing_number_identifier_type.id],:group=>"patient_id")
        patient_ids = all_filing_numbers.collect{|i|i.patient_id}
        patient_to_be_archived = Encounter.find_by_sql(["
          SELECT patient_id, MAX(encounter_datetime) AS last_encounter_id
          FROM encounter
          WHERE patient_id IN (?)
          AND encounter_type IN (?)
          GROUP BY patient_id
          ORDER BY last_encounter_id
          LIMIT 1",patient_ids, encounter_type_ids]).first.patient rescue nil

        if patient_to_be_archived.blank?
          patient_to_be_archived = PatientIdentifier.find(:last,:conditions =>["identifier_type = ?",
              filing_number_identifier_type.id],
            :group=>"patient_id",:order => "identifier DESC").patient rescue nil
        end
      end

      if PatientService.get_patient_identifier(patient, 'Archived filing number')
        #voids the record- if patient has a dormant filing number
        current_archive_filing_numbers = patient.patient_identifiers.collect{|identifier|
          identifier if identifier.identifier_type == archive_identifier_type.id and identifier.voided
        }.compact
        current_archive_filing_numbers.each do | filing_number |
          filing_number.voided = 1
          filing_number.void_reason = "patient assign new active filing number"
          filing_number.voided_by = current_user.id
          filing_number.date_voided = Time.now()
          filing_number.save
        end
      end

      unless patient_to_be_archived.blank?
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = patient.id
        filing_number.identifier = PatientService.get_patient_identifier(patient_to_be_archived, 'Filing number')
        filing_number.identifier_type = filing_number_identifier_type.id
        filing_number.save

        current_active_filing_numbers = patient_to_be_archived.patient_identifiers.collect{|identifier|
          identifier if identifier.identifier_type == filing_number_identifier_type.id and not identifier.voided
        }.compact
        current_active_filing_numbers.each do | filing_number |
          filing_number.voided = 1
          filing_number.void_reason = "Archived - filing number given to:#{self.id}"
          filing_number.voided_by = current_user.id
          filing_number.date_voided = Time.now()
          filing_number.save
        end
      else
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = patient.id
        filing_number.identifier = next_filing_number
        filing_number.identifier_type = filing_number_identifier_type.id
        filing_number.save
      end
      true
    end
  end

  def diabetes_treatments
    session_date = session[:datetime].to_date rescue Date.today
    #find the user priviledges
    @super_user = false
    @nurse = false
    @clinician  = false
    @doctor     = false
    @registration_clerk  = false

    @user = User.find(current_user.user_id)
    @user_privilege = @user.user_roles.collect{|x|x.role}

    if @user_privilege.first.downcase.include?("superuser")
      @super_user = true
    elsif @user_privilege.first.downcase.include?("clinician")
      @clinician  = true
    elsif @user_privilege.first.downcase.include?("nurse")
      @nurse  = true
    elsif @user_privilege.first.downcase.include?("doctor")
      @doctor     = true
    elsif @user_privilege.first.downcase.include?("registration clerk")
      @registration_clerk  = true
    end
    
    @patient      = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    void_encounter if (params[:void] && params[:void] == 'true')
    #@encounters   = @patient.encounters.current.active.find(:all)
    @encounters   = @patient.encounters.find(:all, :conditions => ['DATE(encounter_datetime) = ?',session_date.to_date])
    excluded_encounters = ["Registration", "Diabetes history","Complications", #"Diabetes test",
      "General health", "Diabetes treatments", "Diabetes admissions","Hospital admissions",
      "Hypertension management", "Past diabetes medical history"]
    @encounter_names = @patient.encounters.active.map{|encounter| encounter.name}.uniq.delete_if{ |encounter| excluded_encounters.include? encounter.humanize } rescue []
    ignored_concept_id = Concept.find_by_name("NO").id;

    @observations = Observation.find(:all, :order => 'obs_datetime DESC', 
      :limit => 50, :conditions => ["person_id= ? AND obs_datetime < ? AND value_coded != ?",
        @patient.patient_id, Time.now.to_date, ignored_concept_id])

    @observations.delete_if { |obs| obs.value_text.downcase == "no" rescue nil }

    # delete encounters that are not required for display on patient's summary
    @lab_results_ids = [Concept.find_by_name("Urea").id, Concept.find_by_name("Urine Protein").id, Concept.find_by_name("Creatinine").id]
    @encounters.map{ |encounter| (encounter.name == "DIABETES TEST" && encounter.observations.delete_if{|obs| !(@lab_results_ids.include? obs.concept.id)})} rescue nil
    @encounters.delete_if{|encounter|(encounter.observations == [])}

    @obs_datetimes = @observations.map { |each|each.obs_datetime.strftime("%d-%b-%Y")}.uniq

    @vitals = Encounter.find(:all, :order => 'encounter_datetime DESC',
      :limit => 50, :conditions => ["patient_id= ? AND encounter_datetime < ? ",
        @patient.patient_id, Time.now.to_date])

    @patient_treatements = DiabetesService.treatments(@patient)

    diabetes_id       = Concept.find_by_name("DIABETES MEDICATION").id

    @patient_diabetes_treatements     = []
    @patient_hypertension_treatements = []

    @patient_diabetes_treatements = DiabetesService.aggregate_treatments(@patient)

    selected_medical_history = ['DIABETES DIAGNOSIS DATE','SERIOUS CARDIAC PROBLEM','STROKE','HYPERTENSION','TUBERCULOSIS']
    @medical_history_ids = selected_medical_history.map { |medical_history| Concept.find_by_name(medical_history).id }
    @significant_medical_history = []
    @observations.each { |obs| @significant_medical_history << obs if @medical_history_ids.include? obs.concept_id}

	patient_bean = PatientService.get_patient(@patient.person)
    @arv_number = patient_bean.arv_number rescue nil
    @status     = PatientService.patient_hiv_status(@patient)
    #@status =Concept.find(Observation.find(:first,  :conditions => ["voided = 0 AND person_id= ? AND concept_id = ?",@patient.person.id, Concept.find_by_name('HIV STATUS').id], :order => 'obs_datetime DESC').value_coded).name.name rescue 'UNKNOWN'
    @hiv_test_date    = PatientService.hiv_test_date(@patient.id).strftime("%d/%b/%Y") rescue "UNKNOWN"
    @hiv_test_date = "Unkown" if @hiv_test_date.blank?
    @remote_art_info  = DiabetesService.remote_art_info(patient_bean.national_id) rescue nil

    @recents = DiabetesService.patient_recent_screen_complications(@patient.patient_id)

    # set the patient's medication period
    @patient_medication_period = DiabetesService.patient_diabetes_medication_duration(@patient.patient_id)
    
    render :layout => false
  end

  def important_medical_history
      recent_screen_complications
  end
  
  def recent_screen_complications
	get_recent_screen_complications
	render :layout => false   
  end
  
  def get_recent_screen_complications
    session_date = session[:datetime].to_date rescue Date.today
    #find the user priviledges
    @super_user = false
    @nurse = false
    @clinician  = false
    @doctor     = false
    @registration_clerk  = false

    @user = User.find(current_user.user_id)
    @user_privilege = @user.user_roles.collect{|x|x.role}

    if @user_privilege.first.downcase.include?("superuser")
      @super_user = true
    elsif @user_privilege.first.downcase.include?("clinician")
      @clinician  = true
    elsif @user_privilege.first.downcase.include?("nurse")
      @nurse  = true
    elsif @user_privilege.first.downcase.include?("doctor")
      @doctor     = true
    elsif @user_privilege.first.downcase.include?("registration clerk")
      @registration_clerk  = true
    end

    @patient      = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil

    void_encounter if (params[:void] && params[:void] == 'true')
    #@encounters   = @patient.encounters.current.active.find(:all)
    @encounters   = @patient.encounters.find(:all, :conditions => ['DATE(encounter_datetime) = ?',session_date.to_date])
    excluded_encounters = ["Registration", "Diabetes history","Complications", #"Diabetes test",
      "General health", "Diabetes treatments", "Diabetes admissions","Hospital admissions",
      "Hypertension management", "Past diabetes medical history"]
    @encounter_names = @patient.encounters.active.map{|encounter| encounter.name}.uniq.delete_if{ |encounter| excluded_encounters.include? encounter.humanize } rescue []
    ignored_concept_id = Concept.find_by_name("NO").id;

    @observations = Observation.find(:all, :order => 'obs_datetime DESC', 
      :limit => 50, :conditions => ["person_id= ? AND obs_datetime < ? AND value_coded != ?",
        @patient.patient_id, Time.now.to_date, ignored_concept_id])

    @observations.delete_if { |obs| obs.value_text.downcase == "no" rescue nil }

    # delete encounters that are not required for display on patient's summary
    @lab_results_ids = [Concept.find_by_name("Urea").id, Concept.find_by_name("Urine Protein").id, Concept.find_by_name("Creatinine").id]
    @encounters.map{ |encounter| (encounter.name == "DIABETES TEST" && encounter.observations.delete_if{|obs| !(@lab_results_ids.include? obs.concept.id)})} rescue nil
    @encounters.delete_if{|encounter|(encounter.observations == [])}

    @obs_datetimes = @observations.map { |each|each.obs_datetime.strftime("%d-%b-%Y")}.uniq

    @vitals = Encounter.find(:all, :order => 'encounter_datetime DESC',
      :limit => 50, :conditions => ["patient_id= ? AND encounter_datetime < ? ",
        @patient.patient_id, Time.now.to_date])

    @patient_treatements = DiabetesService.treatments(@patient)

    diabetes_id       = Concept.find_by_name("DIABETES MEDICATION").id

    @patient_diabetes_treatements     = []
    @patient_hypertension_treatements = []

    @patient_diabetes_treatements = DiabetesService.aggregate_treatments(@patient)

    selected_medical_history = ['DIABETES DIAGNOSIS DATE','SERIOUS CARDIAC PROBLEM','STROKE','HYPERTENSION','TUBERCULOSIS']
    @medical_history_ids = selected_medical_history.map { |medical_history| Concept.find_by_name(medical_history).id }
    @significant_medical_history = []
    @observations.each { |obs| @significant_medical_history << obs if @medical_history_ids.include? obs.concept_id}

	patient_bean = PatientService.get_patient(@patient.person)

    @arv_number = patient_bean.arv_number
    @status     = PatientService.patient_hiv_status(@patient)
    
    #@status =Concept.find(Observation.find(:first,  :conditions => ["voided = 0 AND person_id= ? AND concept_id = ?",@patient.person.id, Concept.find_by_name('HIV STATUS').id], :order => 'obs_datetime DESC').value_coded).name.name rescue 'UNKNOWN'
    @hiv_test_date    = PatientService.hiv_test_date(@patient.id).strftime("%d/%b/%Y") rescue "UNKNOWN"
    @hiv_test_date = "Unkown" if @hiv_test_date.blank?
    @remote_art_info  = Patient.remote_art_info(@patient.national_id) rescue nil

    @recents = DiabetesService.patient_recent_screen_complications(@patient.patient_id)

    # set the patient's medication period
    @patient_medication_period = DiabetesService.patient_diabetes_medication_duration(@patient.patient_id)
  end

  def patient_medical_history
  
      @patient = Patient.find(params[:patient_id] || session[:patient_id]) if (!@patient)
      void_encounter if (params[:void] && params[:void] == 'true')

      @encounter_type_ids = []
      encounters_list = ["initial diabetes complications","complications",
        "diabetes history", "diabetes treatments",
        "hospital admissions", "general health",
        "hypertension management",
        "past diabetes medical history"]

      @encounter_type_ids = EncounterType.find_all_by_name(encounters_list).each{|e| e.encounter_type_id}

      @encounters   = @patient.encounters.find(:all, :order => 'encounter_datetime DESC',
        :conditions => ["patient_id= ? AND encounter_type in (?)",
          @patient.patient_id,@encounter_type_ids])
                      
      @encounter_names = @patient.encounters.map{|encounter| encounter.name}.uniq

      @encounter_datetimes = @encounters.map { |each|each.encounter_datetime.strftime("%b-%Y")}.uniq
    render :template => false, :layout => false
  end
  
	def hiv
		get_recent_screen_complications
		render :template => 'patients/hiv', :layout => false
	end

  def edit_demographics
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @person = @patient.person
    @diabetes_number = DiabetesService.diabetes_number(@patient)
    @ds_number = DiabetesService.ds_number(@patient)
    @patient_bean = PatientService.get_patient(@person)
    @address = @person.addresses.last
    
	@phone = PatientService.phone_numbers(@person)['Cell phone number']
	@phone = 'Unknown' if @phone.blank?
    render :layout => 'edit_demographics'
  end
  
  def dashboard_graph
    session_date = session[:datetime].to_date rescue Date.today
    @patient      = Patient.find(params[:id] || session[:patient_id]) rescue nil
    
    patient_bean = PatientService.get_patient(@patient.person)

    #@encounters   = @patient.encounters.current.active.find(:all)
    @encounters   = @patient.encounters.find(:all, :conditions => ['DATE(encounter_datetime) = ?',session_date.to_date])
    excluded_encounters = ["Registration", "Diabetes history","Complications", #"Diabetes test",
      "General health", "Diabetes treatments", "Diabetes admissions","Hospital admissions",
      "Hypertension management", "Past diabetes medical history"] 
    @encounter_names = @patient.encounters.active.map{|encounter| encounter.name}.uniq.delete_if{ |encounter| excluded_encounters.include? encounter.humanize } rescue []
    ignored_concept_id = Concept.find_by_name("NO").id;

    @observations = Observation.find(:all, :order => 'obs_datetime DESC', 
      :limit => 50, :conditions => ["person_id= ? AND obs_datetime < ? AND value_coded != ?",
        @patient.patient_id, Time.now.to_date, ignored_concept_id])

    @observations.delete_if { |obs| obs.value_text.downcase == "no" rescue nil }

    # delete encounters that are not required for display on patient's summary
    @lab_results_ids = [Concept.find_by_name("Urea").id, Concept.find_by_name("Urine Protein").id, Concept.find_by_name("Creatinine").id]
    @encounters.map{ |encounter| (encounter.name == "DIABETES TEST" && encounter.observations.delete_if{|obs| !(@lab_results_ids.include? obs.concept.id)})} rescue nil
    @encounters.delete_if{|encounter|(encounter.observations == [])}

    @obs_datetimes = @observations.map { |each|each.obs_datetime.strftime("%d-%b-%Y")}.uniq

    @vitals = Encounter.find(:all, :order => 'encounter_datetime DESC',
      :limit => 50, :conditions => ["patient_id= ? AND encounter_datetime < ? ",
        @patient.patient_id, Time.now.to_date])

    @patient_treatements = DiabetesService.treatments(@patient)

    diabetes_id       = Concept.find_by_name("DIABETES MEDICATION").id

    @patient_diabetes_treatements     = []
    @patient_hypertension_treatements = []

    @patient_diabetes_treatements = DiabetesService.aggregate_treatments(@patient)

    selected_medical_history = ['DIABETES DIAGNOSIS DATE','SERIOUS CARDIAC PROBLEM','STROKE','HYPERTENSION','TUBERCULOSIS']
    @medical_history_ids = selected_medical_history.map { |medical_history| Concept.find_by_name(medical_history).id }
    @significant_medical_history = []
    @observations.each { |obs| @significant_medical_history << obs if @medical_history_ids.include? obs.concept_id}

    @arv_number = patient_bean.arv_number rescue nil
    @status     = PatientService.patient_hiv_status(@patient)
    #@status =Concept.find(Observation.find(:first,  :conditions => ["voided = 0 AND person_id= ? AND concept_id = ?",@patient.person.id, Concept.find_by_name('HIV STATUS').id], :order => 'obs_datetime DESC').value_coded).name.name rescue 'UNKNOWN'
    @hiv_test_date    = PatientService.hiv_test_date(@patient.id).strftime("%d/%b/%Y") rescue "UNKNOWN"
    @hiv_test_date = "Unkown" if @hiv_test_date.blank?
    @remote_art_info  = DiabetesService.remote_art_info(patient_bean.national_id) rescue nil


	@recents = DiabetesService.patient_recent_screen_complications(@patient.patient_id)

    # set the patient's medication period
    @patient_medication_period = DiabetesService.patient_diabetes_medication_duration(@patient.patient_id)
    render :layout => false
  end
  
  def graph_main
    session_date = session[:datetime].to_date rescue Date.today
    
    @patient      = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    #@encounters   = @patient.encounters.current.active.find(:all)
    @encounters   = @patient.encounters.find(:all, :conditions => ['DATE(encounter_datetime) = ?',session_date.to_date])
    excluded_encounters = ["Registration", "Diabetes history","Complications", #"Diabetes test",
      "General health", "Diabetes treatments", "Diabetes admissions","Hospital admissions",
      "Hypertension management", "Past diabetes medical history"] 
    @encounter_names = @patient.encounters.active.map{|encounter| encounter.name}.uniq.delete_if{ |encounter| excluded_encounters.include? encounter.humanize } rescue []
    ignored_concept_id = Concept.find_by_name("NO").id;

    @observations = Observation.find(:all, :order => 'obs_datetime DESC', 
      :limit => 50, :conditions => ["person_id= ? AND obs_datetime < ? AND value_coded != ?",
        @patient.patient_id, Time.now.to_date, ignored_concept_id])

    @observations.delete_if { |obs| obs.value_text.downcase == "no" rescue nil }

    # delete encounters that are not required for display on patient's summary
    @lab_results_ids = [Concept.find_by_name("Urea").id, Concept.find_by_name("Urine Protein").id, Concept.find_by_name("Creatinine").id]
    @encounters.map{ |encounter| (encounter.name == "DIABETES TEST" && encounter.observations.delete_if{|obs| !(@lab_results_ids.include? obs.concept.id)})}
    @encounters.delete_if{|encounter|(encounter.observations == [])}

    @obs_datetimes = @observations.map { |each|each.obs_datetime.strftime("%d-%b-%Y")}.uniq

    @vitals = Encounter.find(:all, :order => 'encounter_datetime DESC',
      :limit => 50, :conditions => ["patient_id= ? AND encounter_datetime < ? ",
        @patient.patient_id, Time.now.to_date])

    @patient_treatements = DiabetesService.treatments(@patient)

    diabetes_id       = Concept.find_by_name("DIABETES MEDICATION").id

    @patient_diabetes_treatements     = []
    @patient_hypertension_treatements = []

    @patient_diabetes_treatements = DiabetesService.aggregate_treatments(@patient)

    selected_medical_history = ['DIABETES DIAGNOSIS DATE','SERIOUS CARDIAC PROBLEM','STROKE','HYPERTENSION','TUBERCULOSIS']
    @medical_history_ids = selected_medical_history.map { |medical_history| Concept.find_by_name(medical_history).id }
    @significant_medical_history = []
    @observations.each { |obs| @significant_medical_history << obs if @medical_history_ids.include? obs.concept_id}
    
	patient_bean = PatientService.get_patient(@patient.person)

    @arv_number = patient_bean.arv_number
    @status     = PatientService.patient_hiv_status(@patient)
    
    #@status =Concept.find(Observation.find(:first,  :conditions => ["voided = 0 AND person_id= ? AND concept_id = ?",@patient.person.id, Concept.find_by_name('HIV STATUS').id], :order => 'obs_datetime DESC').value_coded).name.name rescue 'UNKNOWN'
    @hiv_test_date    = PatientService.hiv_test_date(@patient.id).strftime("%d/%b/%Y") rescue "UNKNOWN"
    @hiv_test_date = "Unkown" if @hiv_test_date.blank?
    @remote_art_info  = Patient.remote_art_info(@patient.national_id) rescue nil

    @recents = DiabetesService.patient_recent_screen_complications(@patient.patient_id)

    # set the patient's medication period
    @patient_medication_period = DiabetesService.patient_diabetes_medication_duration(@patient.patient_id)
    render :layout => 'menu'    
    
  end
  
  def generate_booking
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil

    @type = EncounterType.find_by_name("APPOINTMENT").id rescue nil
    if(@type)
      @enc = Encounter.find(:all, :conditions =>
          ["voided = 0 AND encounter_type = ?", @type])

      @counts = {}

      @enc.each do |e|
      	 observations = []
         observations = e.observations
       
			   observations.each do |obs| 
					  if !obs.value_datetime.blank?
					    obs_date = obs.value_datetime
					    yr = obs_date.to_date.strftime("%Y")
					    mt = obs_date.to_date.strftime("%m").to_i-1
					    dy = obs_date.to_date.strftime("%d").to_i

					    if(!@counts[(yr.to_s + "-" + mt.to_s + "-" + dy.to_s)])
					      @counts[(yr.to_s + "-" + mt.to_s + "-" + dy.to_s)] = {}
					      @counts[(yr.to_s + "-" + mt.to_s + "-" + dy.to_s)]["count"] = 0
					    end

					    @counts[(yr.to_s + "-" + mt.to_s + "-" + dy.to_s)][e.patient_id] = true
					    @counts[(yr.to_s + "-" + mt.to_s + "-" + dy.to_s)]["count"] += 1
					  end
			    end
      end
    end
    
  end
  
  def remove_booking
    if(params[:patient_id])
      @type = EncounterType.find_by_name("APPOINTMENT").id rescue nil
      @patient = Patient.find(params[:patient_id])
      
      if(@type)
        @enc = @patient.encounters.find(:all, :joins => :observations,
              :conditions => ['encounter_type = ?', @type])
        
        if(@enc)
          reason = ""

          if(params[:appointmentDate])
            if(params[:appointmentDate].to_date < Time.now.to_date)
              reason = "Defaulted"
            elsif(params[:appointmentDate].to_date == Time.now.to_date)
              reason = "Attended"
            elsif(params[:appointmentDate].to_date > Time.now.to_date)
              reason = "Pre-cancellation"
            else
              reason = "General reason"
            end
          end

          @enc.each do |encounter|
            
            @voided = false

            encounter.observations.each do |o|

							next if o.value_datetime.blank?

              if o.value_datetime.to_date == params[:appointmentDate].to_date
                o.update_attributes(:voided => 1, :date_voided => Time.now.to_date,
                :voided_by => current_user.user_id, :void_reason => reason)

                @voided = true
              end
            end
            
            if @voided == true
              encounter.update_attributes(:voided => 1, :date_voided => Time.now.to_date,
                :voided_by => current_user.user_id, :void_reason => reason)
            end
          end
          
        end
      end
    end
    render :text => ""
  end
  
  def complications
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    void_encounter if (params[:void] && params[:void] == 'true')
    @person = @patient.person
    @encounters = @patient.encounters.find_all_by_encounter_type(EncounterType.find_by_name('DIABETES TEST').id)
    @observations = @encounters.map(&:observations).flatten
    @obs_datetimes = @observations.map { |each|each.obs_datetime.strftime("%d-%b-%Y")}.uniq
    @address = @person.addresses.last

    diabetes_test_id = EncounterType.find_by_name('Diabetes Test').id

    #TODO: move this code to Patient model
    # Creatinine
    creatinine_id = Concept.find_by_name('CREATININE').id
    @creatinine_obs = @patient.person.observations.find(:all,
      :joins => :encounter,
      :conditions => ['encounter_type = ? AND concept_id = ?',
        diabetes_test_id, creatinine_id],
      :order => 'obs_datetime DESC')

    # Urine Protein
    urine_protein_id = Concept.find_by_name('URINE PROTEIN').id
    @urine_protein_obs = @patient.person.observations.find(:all,
      :joins => :encounter,
      :conditions => ['encounter_type = ? AND concept_id = ?',
        diabetes_test_id, urine_protein_id],
      :order => 'obs_datetime DESC')

    # Foot Check
    @foot_check_encounters = @patient.encounters.find(:all,
      :joins => :observations,
      :conditions => ['concept_id IN (?)',
        ConceptName.find_all_by_name(['RIGHT FOOT/LEG',
            'LEFT FOOT/LEG', 'LEFT HAND/ARM', 'RIGHT HAND/ARM']).map(&:concept_id)],
      :order => 'obs_datetime DESC').uniq

    if @foot_check_encounters.nil?
      @foot_check_encounters = []
    end

    @foot_check_obs = {}
    
    @foot_check_encounters.each{|e|
      value = @patient.person.observations.find(:all,
        :joins => :encounter,
        :conditions => ['encounter_type = ? AND encounter.encounter_id IN (?)',
          diabetes_test_id, e.encounter_id],
        :order => 'obs_datetime DESC')

      unless value.nil?
        @foot_check_obs[e.encounter_id] = value
      end
    }

    # Visual Acuity RIGHT EYE FUNDOSCOPY
    @visual_acuity_encounters = @patient.encounters.find(:all,
      :joins => :observations,
      :conditions => ['concept_id IN (?)',
        ConceptName.find_all_by_name(['LEFT EYE VISUAL ACUITY',
            'RIGHT EYE VISUAL ACUITY']).map(&:concept_id)],
      :order => 'obs_datetime DESC').uniq

    if @visual_acuity_encounters.nil?
      @visual_acuity_encounters = []
    end
    
    @visual_acuity_obs = {}
    
    @visual_acuity_encounters.each{|e|
      @visual_acuity_obs[e.encounter_id] = @patient.person.observations.find(:all,
        :joins => :encounter,
        :conditions => ['encounter_type = ? AND encounter.encounter_id = ?',
          diabetes_test_id, e.encounter_id],
        :order => 'obs_datetime DESC')
    }


    # Fundoscopy
    @fundoscopy_encounters = @patient.encounters.find(:all,
      :joins => :observations,
      :conditions => ['concept_id IN (?)',
        ConceptName.find_all_by_name(['LEFT EYE FUNDOSCOPY',
            'RIGHT EYE FUNDOSCOPY']).map(&:concept_id)],
      :order => 'obs_datetime DESC').uniq

    if @fundoscopy_encounters.nil?
      @fundoscopy_encounters = []
    end

    @fundoscopy_obs = {}
    
    @fundoscopy_encounters.each{|e|
      @fundoscopy_obs[e.encounter_id] = @patient.person.observations.find(:all,
        :joins => :encounter,
        :conditions => ['encounter_type = ? AND encounter.encounter_id IN (?)',
          diabetes_test_id, e.encounter_id],
        :order => 'obs_datetime DESC')
    }
    
    # Urea
    urea_id = Concept.find_by_name('UREA').id
    @urea_obs = @patient.person.observations.find(:all,
      :joins => :encounter,
      :conditions => ['encounter_type = ? AND concept_id = ?',
        diabetes_test_id, urea_id],
      :order => 'obs_datetime DESC')


    # Macrovascular
    macrovascular_id = Concept.find_by_name('MACROVASCULAR').id
    @macrovascular_obs = @patient.person.observations.find(:all,
      :joins => :encounter,
      :conditions => ['encounter_type = ? AND concept_id = ?',
        diabetes_test_id, macrovascular_id],
      :order => 'obs_datetime DESC')
    render :layout => 'complications'
  end
  
  def print_complications
    @patient = Patient.find(params[:id] || params[:patient_id] || session[:patient_id]) rescue nil
    next_url = "/patients/complications?patient_id=#{@patient.id}"
    print_and_redirect("/patients/complications_label/?patient_id=#{@patient.id}", next_url)
  end
  
  def complications_label
    print_string = DiabetesService.complications_label(@patient, current_user.user_id) #rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end
  
  def void_encounter
    @encounter = Encounter.find(params[:encounter_id])
    ActiveRecord::Base.transaction do
      @encounter.void
    end
    return
  end

  def dashboard_display_number_of_booked_patients                                                
    date = (params[:date].sub("Next appointment:","").sub(/\((.*)/,"")).to_date                                                
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id
    count = Observation.count(:all,
            :joins => "INNER JOIN encounter e USING(encounter_id)",:group => "value_datetime",
            :conditions =>["concept_id = ? AND encounter_type = ? AND value_datetime >= ? AND value_datetime <= ?",
            concept_id,encounter_type.id,date.strftime('%Y-%m-%d 00:00:00'),date.strftime('%Y-%m-%d 23:59:59')])
    count = count.values unless count.blank?
    count = '0' if count.blank?
    render :text => "Next appointment: #{date.strftime('%d %B %Y')} (#{count})"
  end 

end
