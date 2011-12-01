class PeopleController < ApplicationController
    
  def index
    redirect_to "/clinic"
  end

  def new
    @occupations = occupations
  end

  def identifiers
  end

  def create_remote
    person_params = {"occupation"=> params[:occupation],
 "age_estimate"=> params['patient_age']['age_estimate'],
 "cell_phone_number"=> params['cell_phone']['identifier'],
 "birth_month"=> params[:patient_month],
 "addresses"=>{ "address2" => params['p_address']['identifier'],
                "address1" => params['p_address']['identifier'],
 "city_village"=> params['patientaddress']['city_village'],
 "county_district"=> params[:birthplace] },
 "gender" => params['patient']['gender'],
 "birth_day" => params[:patient_day],
 "names"=> {"family_name2"=>"Unknown",
 "family_name"=> params['patient_name']['family_name'],
 "given_name"=> params['patient_name']['given_name'] },
 "birth_year"=> params[:patient_year] }

    #raise person_params.to_yaml
    if User.current_user.blank?
      User.current_user = User.find(1)
    end rescue []

    if Location.current_location.blank?
      Location.current_location = Location.find(CoreService.get_global_property_value('current_health_center_id'))
    end rescue []

    person = PatientService.create_from_form(person_params)
    if person
      patient = Patient.new()
      patient.patient_id = person.id
      patient.save
      PatientService.patient_national_id_label(patient)
    end
    render :text => PatientService.remote_demographics(person).to_json
  end

  def demographics
    # Search by the demographics that were passed in and then return demographics
    people = PatientService.find_person_by_demographics(params)
    result = people.empty? ? {} : PatientService.demographics(people.first)
    render :text => result.to_json
  end
  
  def art_information
    national_id = params["person"]["patient"]["identifiers"]["National id"] rescue nil
    art_info = Patient.art_info_for_remote(national_id)
    art_info = art_info_for_remote(national_id)
    render :text => art_info.to_json
  end
 
  def search
    found_person = nil
    if params[:identifier]
      local_results = PatientService.search_by_identifier(params[:identifier])

      if local_results.length > 1
        @people = PatientService.person_search(params)
      elsif local_results.length == 1
        found_person = local_results.first
      else
        # TODO - figure out how to write a test for this
        # This is sloppy - creating something as the result of a GET
        found_person_data = PatientService.find_remote_person_by_identifier(params[:identifier])
        found_person = PatientService.create_from_form(found_person_data['person']) unless found_person_data.nil?
      end
      if found_person
        if params[:relation]
          redirect_to search_complete_url(found_person.id, params[:relation]) and return
        else
          redirect_to :action => 'confirm', :found_person_id => found_person.id, :relation => params[:relation] and return
        end
      end
    end
    @relation = params[:relation]
    @people = PatientService.person_search(params)
    @patients = []
    @people.each do | person |
        patient = PatientService.get_patient(person) rescue nil
        @patients << patient
    end
    
  end
  
  def confirm
    session_date = session[:datetime] || Date.today
    if request.post?
      redirect_to search_complete_url(params[:found_person_id], params[:relation]) and return
    end
    @found_person_id = params[:found_person_id] 
    @relation = params[:relation]
    @person = Person.find(@found_person_id) rescue nil
    @task = main_next_task(Location.current_location, @person.patient, session_date.to_date)
    @arv_number = PatientService.get_patient_identifier(@person, 'ARV Number')
	  @patient_bean = PatientService.get_patient(@person)
    render :layout => 'menu'
  end

  def tranfer_patient_in
    @data_demo = {}
    if request.post?
      params[:data].split(',').each do | data |
        if data[0..4] == "Name:"
          @data_demo['name'] = data.split(':')[1]
          next
        end
        if data.match(/guardian/i)
          @data_demo['guardian'] = data.split(':')[1]
          next
        end
        if data.match(/sex/i)
          @data_demo['sex'] = data.split(':')[1]
          next
        end
        if data[0..3] == 'DOB:'
          @data_demo['dob'] = data.split(':')[1]
          next
        end
        if data.match(/National ID:/i)
          @data_demo['national_id'] = data.split(':')[1]
          next
        end
        if data[0..3] == "BMI:"
          @data_demo['bmi'] = data.split(':')[1]
          next
        end
        if data.match(/ARV number:/i)
          @data_demo['arv_number'] = data.split(':')[1]
          next
        end
        if data.match(/Address:/i)
          @data_demo['address'] = data.split(':')[1]
          next
        end
        if data.match(/1st pos HIV test site:/i)
          @data_demo['first_positive_hiv_test_site'] = data.split(':')[1]
          next
        end
        if data.match(/1st pos HIV test date:/i)
          @data_demo['first_positive_hiv_test_date'] = data.split(':')[1]
          next
        end
        if data.match(/FU:/i)
          @data_demo['agrees_to_followup'] = data.split(':')[1]
          next
        end
        if data.match(/1st line date:/i)
          @data_demo['date_of_first_line_regimen'] = data.split(':')[1]
          next
        end
        if data.match(/SR:/i)
          @data_demo['reason_for_art_eligibility'] = data.split(':')[1]
          next
        end
      end
    end
    render :layout => "menu"
  end
 
  # This method is just to allow the select box to submit, we could probably do this better
  def select
    if params[:person] != '0' && Person.find(params[:person]).dead == 1
      redirect_to :controller => :patients, :action => :show, :id => params[:person]
    else
      redirect_to search_complete_url(params[:person], params[:relation]) and return unless params[:person].blank? || params[:person] == '0'

      redirect_to :action => :new, :gender => params[:gender], :given_name => params[:given_name], :family_name => params[:family_name], :family_name2 => params[:family_name2], :address2 => params[:address2], :identifier => params[:identifier], :relation => params[:relation]
    end
  end
 
  def create
    success = false
    Person.session_datetime = session[:datetime].to_date rescue Date.today

    #for now BART2 will use BART1 for patient/person creation until we upgrade BART1 to 2
    #if GlobalProperty.find_by_property('create.from.remote') and property_value == 'yes'
    #then we create person from remote machine
    if create_from_remote
      person_from_remote = PatientService.create_remote_person(params)
      person = PatientService.create_from_form(person_from_remote["person"]) unless person_from_remote.blank?

      if !person.blank?
        success = true
        person.patient.remote_national_id
      end
    else
      success = true
      person = PatientService.create_from_form(params[:person])
    end

    if params[:person][:patient] && success
      PatientService.patient_national_id_label(person.patient)
      unless (params[:relation].blank?)
        redirect_to search_complete_url(person.id, params[:relation]) and return
      else

       tb_session = false
       if User.current_user.activities.include?('Manage Lab Orders') or User.current_user.activities.include?('Manage Lab Results') or
        User.current_user.activities.include?('Manage Sputum Submissions') or User.current_user.activities.include?('Manage TB Clinic Visits') or
         User.current_user.activities.include?('Manage TB Reception Visits') or User.current_user.activities.include?('Manage TB Registration Visits') or
          User.current_user.activities.include?('Manage HIV Status Visits')
         tb_session = true
       end

        if use_filing_number and not tb_session
          PatientService.set_patient_filing_number(person.patient) 
          archived_patient = PatientService.patient_to_be_archived(person.patient)
          message = PatientService.patient_printing_message(person.patient,archived_patient,creating_new_patient = true)
          unless message.blank?
            print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}" , next_task(person.patient),message,true,person.id)
          else
            print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}", next_task(person.patient)) 
          end
        else
          print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
        end
      end
    else
      # Does this ever get hit?
      redirect_to :action => "index"
    end
  end

  def set_datetime
    if request.post?
      unless params[:set_day]== "" or params[:set_month]== "" or params[:set_year]== ""
        # set for 1 second after midnight to designate it as a retrospective date
        date_of_encounter = Time.mktime(params[:set_year].to_i,
                                        params[:set_month].to_i,                                
                                        params[:set_day].to_i,0,0,1) 
        session[:datetime] = date_of_encounter #if date_of_encounter.to_date != Date.today
      end
      unless params[:id].blank?
        redirect_to next_task(Patient.find(params[:id])) 
      else
        redirect_to :action => "index"
      end
    end
    @patient_id = params[:id]
  end

  def reset_datetime
    session[:datetime] = nil
    if params[:id].blank?
      redirect_to :action => "index" and return
    else
      redirect_to "/patients/show/#{params[:id]}" and return
    end
  end

  def find_by_arv_number
    if request.post?
      redirect_to :action => 'search' ,
        :identifier => "#{PatientIdentifier.site_prefix} #{params[:arv_number]}" and return
    end
  end
  
  # List traditional authority containing the string given in params[:value]
  def traditional_authority
    district_id = District.find_by_name("#{params[:filter_value]}").id
    traditional_authority_conditions = ["name LIKE (?) AND district_id = ?", "#{params[:search_string]}%", district_id]

    traditional_authorities = TraditionalAuthority.find(:all,:conditions => traditional_authority_conditions, :order => 'name')
    traditional_authorities = traditional_authorities.map do |t_a|
      "<li value='#{t_a.name}'>#{t_a.name}</li>"
    end
    render :text => traditional_authorities.join('') and return
  end

    # Regions containing the string given in params[:value]
  def region
    region_conditions = ["name LIKE (?)", "#{params[:value]}%"]

    regions = Region.find(:all,:conditions => region_conditions, :order => 'name')
    regions = regions.map do |r|
      "<li value='#{r.name}'>#{r.name}</li>"
    end
    render :text => regions.join('') and return
  end

    # Districts containing the string given in params[:value]
  def district
    region_id = Region.find_by_name("#{params[:filter_value]}").id
    region_conditions = ["name LIKE (?) AND region_id = ? ", "#{params[:search_string]}%", region_id]

    districts = District.find(:all,:conditions => region_conditions, :order => 'name')
    districts = districts.map do |d|
      "<li value='#{d.name}'>#{d.name}</li>"
    end
    render :text => districts.join('') and return
  end

  def tb_initialization_district
    districts = District.find(:all, :order => 'name')
    districts = districts.map do |d|
      "<li value='#{d.name}'>#{d.name}</li>"
    end
    render :text => districts.join('') and return
  end

    # Villages containing the string given in params[:value]
  def village
    traditional_authority_id = TraditionalAuthority.find_by_name("#{params[:filter_value]}").id
    village_conditions = ["name LIKE (?) AND traditional_authority_id = ?", "#{params[:search_string]}%", traditional_authority_id]

    villages = Village.find(:all,:conditions => village_conditions, :order => 'name')
    villages = villages.map do |v|
      "<li value='#{v.name}'>#{v.name}</li>"
    end
    render :text => villages.join('') and return
  end
  
  # Landmark containing the string given in params[:value]
  def landmark
    landmarks = PersonAddress.find(:all, :select => "DISTINCT address1" , :conditions => ["city_village = (?) AND address1 LIKE (?)", "#{params[:filter_value]}", "#{params[:search_string]}%"])
    landmarks = landmarks.map do |v|
      "<li value='#{v.address1}'>#{v.address1}</li>"
    end
    render :text => landmarks.join('') and return
  end

=begin
  #This method was taken out of encounter model. It is been used in
  #people/index (view) which seems not to be used at present.
  def count_by_type_for_date(date)
    # This query can be very time consuming, because of this we will not consider
    # that some of the encounters on the specific date may have been voided
    ActiveRecord::Base.connection.select_all("SELECT count(*) as number, encounter_type FROM encounter GROUP BY encounter_type")
    todays_encounters = Encounter.find(:all, :include => "type", :conditions => ["DATE(encounter_datetime) = ?",date])
    encounters_by_type = Hash.new(0)
    todays_encounters.each{|encounter|
      next if encounter.type.nil?
      encounters_by_type[encounter.type.name] += 1
    }
    encounters_by_type
  end
=end

  def art_info_for_remote(national_id)

    patient = PatientService.search_by_identifier(national_id).first.patient rescue []
    return {} if patient.blank?

    results = {}
    result_hash = {}

    if PatientService.art_patient?(patient)
      clinic_encounters = ["APPOINTMENT","ART VISIT","VITALS","HIV STAGING",'ART ADHERENCE','DISPENSING','ART_INITIAL']
      clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
      first_encounter_date = patient.encounters.find(:first,
        :order => 'encounter_datetime',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

      last_encounter_date = patient.encounters.find(:first,
        :order => 'encounter_datetime DESC',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'


      art_start_date = PatientService.patient_art_start_date(patient.id).strftime("%d-%b-%Y") rescue 'Uknown'
      last_given_drugs = patient.person.observations.recent(1).question("ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT").last rescue nil
      last_given_drugs = last_given_drugs.value_text rescue 'Uknown'

      program_id = Program.find_by_name('HIV PROGRAM').id
      outcome = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id],:order => "date_enrolled DESC")
      art_clinic_outcome = outcome.patient_states.last.program_workflow_state.concept.fullname rescue 'Unknown'

      date_tested_positive = patient.person.observations.recent(1).question("FIRST POSITIVE HIV TEST DATE").last rescue nil
      date_tested_positive = date_tested_positive.to_s.split(':')[1].strip.to_date.strftime("%d-%b-%Y") rescue 'Uknown'

      cd4_info = patient.person.observations.recent(1).question("CD4 COUNT").all rescue []
      cd4_data_and_date_hash = {}

      (cd4_info || []).map do | obs |
        cd4_data_and_date_hash[obs.obs_datetime.to_date.strftime("%d-%b-%Y")] = obs.value_numeric
      end

      result_hash = {
        'art_start_date' => art_start_date,
        'date_tested_positive' => date_tested_positive,
        'first_visit_date' => first_encounter_date,
        'last_visit_date' => last_encounter_date,
        'cd4_data' => cd4_data_and_date_hash,
        'last_given_drugs' => last_given_drugs,
        'art_clinic_outcome' => art_clinic_outcome,
        'arv_number' => PatientService.get_patient_identifier(patient, 'ARV Number')
      }
    end

    results["person"] = result_hash
    return results
  end

  def art_info_for_remote(national_id)
    patient = PatientService.search_by_identifier(national_id).first.patient rescue []
    return {} if patient.blank?

    results = {}
    result_hash = {}
    
    if PatientService.art_patient?(patient)
      clinic_encounters = ["APPOINTMENT","ART VISIT","VITALS","HIV STAGING",'ART ADHERENCE','DISPENSING','ART_INITIAL']
      clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
      first_encounter_date = patient.encounters.find(:first, 
        :order => 'encounter_datetime',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

      last_encounter_date = patient.encounters.find(:first, 
        :order => 'encounter_datetime DESC',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'
      

      art_start_date = patient.art_start_date.strftime("%d-%b-%Y") rescue 'Uknown'
      last_given_drugs = patient.person.observations.recent(1).question("ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT").last rescue nil
      last_given_drugs = last_given_drugs.value_text rescue 'Uknown'

     program_id = Program.find_by_name('HIV PROGRAM').id
      outcome = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id],:order => "date_enrolled DESC")
      art_clinic_outcome = outcome.patient_states.last.program_workflow_state.concept.fullname rescue 'Unknown'

      date_tested_positive = patient.person.observations.recent(1).question("FIRST POSITIVE HIV TEST DATE").last rescue nil
      date_tested_positive = date_tested_positive.to_s.split(':')[1].strip.to_date.strftime("%d-%b-%Y") rescue 'Uknown'
      
      cd4_info = patient.person.observations.recent(1).question("CD4 COUNT").all rescue []
      cd4_data_and_date_hash = {}

      (cd4_info || []).map do | obs |
        cd4_data_and_date_hash[obs.obs_datetime.to_date.strftime("%d-%b-%Y")] = obs.value_numeric
      end

      result_hash = {
        'art_start_date' => art_start_date,
        'date_tested_positive' => date_tested_positive,
        'first_visit_date' => first_encounter_date,
         'last_visit_date' => last_encounter_date,
        'cd4_data' => cd4_data_and_date_hash,
        'last_given_drugs' => last_given_drugs,
        'art_clinic_outcome' => art_clinic_outcome,
        'arv_number' => PatientService.get_patient_identifier(patient, 'ARV Number')
      }
    end

    results["person"] = result_hash
    return results
  end
  
  def occupations
    ['','Driver','Housewife','Messenger','Business','Farmer','Salesperson','Teacher',
     'Student','Security guard','Domestic worker', 'Police','Office worker',
     'Preschool child','Mechanic','Prisoner','Craftsman','Healthcare Worker','Soldier'].sort.concat(["Other","Unknown"])
  end

  def edit
    # only allow these fields to prevent dangerous 'fields' e.g. 'destroy!'
    valid_fields = ['birthdate','gender']
    unless valid_fields.include? params[:field]
      redirect_to :controller => 'patients', :action => :demographics, :id => params[:id]
      return
    end

    @person = Person.find(params[:id])
    if request.post? && params[:field]
      if params[:field]== 'gender'
        @person.gender = params[:person][:gender]
      elsif params[:field] == 'birthdate'
        if params[:person][:birth_year] == "Unknown"
          @person.set_birthdate_by_age(params[:person]["age_estimate"])
        else
          PatientService.set_birthdate(@person, params[:person]["birth_year"],
                                params[:person]["birth_month"],
                                params[:person]["birth_day"])
        end
        @person.birthdate_estimated = 1 if params[:person]["birthdate_estimated"] == 'true'
        @person.save
      end
      @person.save
      redirect_to :controller => :patients, :action => :edit_demographics, :id => @person.id
    else
      @field = params[:field]
      @field_value = @person.send(@field)
    end
  end
  
private
  
  def search_complete_url(found_person_id, primary_person_id)
    unless (primary_person_id.blank?)
      # Notice this swaps them!
      new_relationship_url(:patient_id => primary_person_id, :relation => found_person_id)
    else
		#
		# Hack reversed to continue testing overnight
		#
		# TODO: This needs to be redesigned!!!!!!!!!!!
		#
      #url_for(:controller => :encounters, :action => :new, :patient_id => found_person_id)
      url_for(:controller => :people, :action => :confirm , :found_person_id =>found_person_id)
    end
  end
end
 
