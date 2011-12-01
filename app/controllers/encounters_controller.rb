class EncountersController < ApplicationController
  def create(params=params, session=session)
    #raise params.to_yaml
	
    if params['encounter']['encounter_type_name'] == 'TB_INITIAL'
      (params[:observations] || []).each do |observation|
        if observation['concept_name'].upcase == 'TRANSFER IN' and observation['value_coded_or_text'] == "YES"
          params[:observations] << {"concept_name" => "TB STATUS","value_coded_or_text" => "Confirmed TB on treatment"}
        end
      end
    end

    if params['encounter']['encounter_type_name'] == 'ART_INITIAL'
      if params[:observations][0]['concept_name'].upcase == 'EVER RECEIVED ART' and params[:observations][0]['value_coded_or_text'].upcase == 'NO'
        observations = []
        (params[:observations] || []).each do |observation|
          next if observation['concept_name'].upcase == 'HAS TRANSFER LETTER'
          next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
          next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
          next if observation['concept_name'].upcase == 'ART NUMBER AT PREVIOUS LOCATION'
          next if observation['concept_name'].upcase == 'DATE ART LAST TAKEN'
          next if observation['concept_name'].upcase == 'LAST ART DRUGS TAKEN'
          next if observation['concept_name'].upcase == 'TRANSFER IN'
          next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
          next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
          observations << observation
        end
      elsif params[:observations][4]['concept_name'].upcase == 'DATE ART LAST TAKEN' and params[:observations][4]['value_datetime'] != 'Unknown'
        observations = []
        (params[:observations] || []).each do |observation|
          next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
          next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
          observations << observation
        end
      end

      params[:observations] = observations unless observations.blank?

      observations = []
      (params[:observations] || []).each do |observation|
        if observation['concept_name'].upcase == 'LOCATION OF ART INITIATION' or observation['concept_name'].upcase == 'CONFIRMATORY HIV TEST LOCATION'
          observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
          observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
          observation['value_coded_or_text'] = ""
        end
        observations << observation
      end

      params[:observations] = observations unless observations.blank?
    end

    if params['encounter']['encounter_type_name'].upcase == 'HIV STAGING'
      observations = []
      (params[:observations] || []).each do |observation|
        if observation['concept_name'].upcase == 'CD4 COUNT'
          observation['value_modifier'] = observation['value_numeric'].match(/<|>/)[0] rescue nil
          observation['value_numeric'] = observation['value_numeric'].match(/[0-9](.*)/i)[0] rescue nil
        end
        if observation['concept_name'].upcase == 'CD4 COUNT LOCATION' or observation['concept_name'].upcase == 'LYMPHOCYTE COUNT LOCATION'
          observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
          observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
          observation['value_coded_or_text'] = ""
        end

        observations << observation
      end
      
      params[:observations] = observations unless observations.blank?
    end

    if params['encounter']['encounter_type_name'].upcase == 'ART ADHERENCE'
      observations = []
      (params[:observations] || []).each do |observation|
        if observation['concept_name'].upcase == 'WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER'
          observation['value_numeric'] = observation['value_text'] rescue nil
          observation['value_text'] =  ""
        end
        observations << observation
      end
      params[:observations] = observations unless observations.blank?
    end

   if params['encounter']['encounter_type_name'].upcase == 'REFER PATIENT OUT?'
      observations = []
      (params[:observations] || []).each do |observation|
        if observation['concept_name'].upcase == 'REFERRAL CLINIC IF REFERRED'
          observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
          observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
          observation['value_coded_or_text'] = ""
        end

        observations << observation
      end

      params[:observations] = observations unless observations.blank?
    end

    @patient = Patient.find(params[:encounter][:patient_id]) rescue nil
    if params[:location]
      if @patient.nil?
        @patient = Patient.find_with_voided(params[:encounter][:patient_id])
      end

      Person.migrated_datetime = params['encounter']['date_created']
      Person.migrated_creator  = params['encounter']['creator'] rescue nil

      # set current location via params if given
      Location.current_location = Location.find(params[:location])
    end
    
    if params['encounter']['encounter_type_name'].to_s.upcase == "APPOINTMENT" && !params[:report_url].nil? && !params[:report_url].match(/report/).nil?
        concept_id = ConceptName.find_by_name("RETURN VISIT DATE").concept_id
        encounter_id_s = Observation.find_by_sql("SELECT encounter_id
                       FROM obs
                       WHERE concept_id = #{concept_id} AND person_id = #{@patient.id}
                            AND DATE(value_datetime) = DATE('#{params[:old_appointment]}') AND voided = 0
                       ").map{|obs| obs.encounter_id}.each do |encounter_id|
                                    Encounter.find(encounter_id).void
                       end   
    end

    # Encounter handling
    encounter = Encounter.new(params[:encounter])
    unless params[:location]
      encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
    else
      encounter.encounter_datetime = params['encounter']['encounter_datetime']
    end

    if !params[:filter][:provider].blank?
     user_person_id = User.find_by_username(params[:filter][:provider]).person_id
     encounter.provider_id = user_person_id
    else
     user_person_id = User.find_by_user_id(encounter[:provider_id]).person_id
     encounter.provider_id = user_person_id
    end

    encounter.save    

    # Observation handling
    (params[:observations] || []).each do |observation|

      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = ['coded_or_text', 'coded_or_text_multiple', 'group_id', 'boolean', 'coded', 'drug', 'datetime', 'numeric', 'modifier', 'text'].map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      observation[:value_text] = observation[:value_text].join(", ") if observation[:value_text].present? && observation[:value_text].is_a?(Array)
      observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
      observation[:encounter_id] = encounter.id
      observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
      observation[:person_id] ||= encounter.patient_id
      observation[:concept_name].upcase ||= "DIAGNOSIS" if encounter.type.name.upcase == "OUTPATIENT DIAGNOSIS"
      
      # Handle multiple select

      if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(String)
        observation[:value_coded_or_text_multiple] = observation[:value_coded_or_text_multiple].split(';')
      end
      
      if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array)
        observation[:value_coded_or_text_multiple].compact!
        observation[:value_coded_or_text_multiple].reject!{|value| value.blank?}
      end  
      
      # convert values from 'mmol/litre' to 'mg/declitre'
      if(observation[:measurement_unit])
        observation[:value_numeric] = observation[:value_numeric].to_f * 18 if ( observation[:measurement_unit] == "mmol/l")
        observation.delete(:measurement_unit)
      end

      if(observation[:parent_concept_name])
        concept_id = Concept.find_by_name(observation[:parent_concept_name]).id rescue nil
        observation[:obs_group_id] = Observation.find(:first, :conditions=> ['concept_id = ? AND encounter_id = ?',concept_id, encounter.id]).id rescue ""
        observation.delete(:parent_concept_name)
      end
      
      extracted_value_numerics = observation[:value_numeric]
      extracted_value_coded_or_text = observation[:value_coded_or_text]

      if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array) && !observation[:value_coded_or_text_multiple].blank?
        
        values = observation.delete(:value_coded_or_text_multiple)
        values.each do |value| 
            observation[:value_coded_or_text] = value
            if observation[:concept_name].humanize == "Tests ordered"
                observation[:accession_number] = Observation.new_accession_number 
            end
            Observation.create(observation) 
        end
      elsif extracted_value_numerics.class == Array
            
        extracted_value_numerics.each do |value_numeric|
          observation[:value_numeric] = value_numeric
          Observation.create(observation)
        end
        
      else      
        observation.delete(:value_coded_or_text_multiple)

        Observation.create(observation)
      end
    end

    # Program handling
    date_enrolled = params[:programs][0]['date_enrolled'].to_time rescue nil
    date_enrolled = session[:datetime] || Time.now() if date_enrolled.blank?
    (params[:programs] || []).each do |program|
      # Look up the program if the program id is set      
      @patient_program = PatientProgram.find(program[:patient_program_id]) unless program[:patient_program_id].blank?
      # If it wasn't set, we need to create it
      unless (@patient_program)
        @patient_program = @patient.patient_programs.create(
          :program_id => program[:program_id],
          :date_enrolled => date_enrolled)          
      end
      # Lots of states bub
      unless program[:states].blank?
        #adding program_state start date
        program[:states][0]['start_date'] = date_enrolled
      end
      (program[:states] || []).each {|state| @patient_program.transition(state) }
    end

    # Identifier handling
    arv_number_identifier_type = PatientIdentifierType.find_by_name('ARV Number').id
    (params[:identifiers] || []).each do |identifier|
      # Look up the identifier if the patient_identfier_id is set      
      @patient_identifier = PatientIdentifier.find(identifier[:patient_identifier_id]) unless identifier[:patient_identifier_id].blank?
      # Create or update
      type = identifier[:identifier_type].to_i rescue nil
      unless (arv_number_identifier_type != type) and @patient_identifier
        arv_number = identifier[:identifier].strip
        if arv_number.match(/(.*)[A-Z]/i).blank?
          if params['encounter']['encounter_type_name'] == 'TB REGISTRATION'
            identifier[:identifier] = "#{PatientIdentifier.site_prefix}-TB-#{arv_number}"
          else
            identifier[:identifier] = "#{PatientIdentifier.site_prefix}-ARV-#{arv_number}"
          end
        end
      end

      if @patient_identifier
        @patient_identifier.update_attributes(identifier)      
      else
        @patient_identifier = @patient.patient_identifiers.create(identifier)
      end
    end

    # person attribute handling
    (params[:person] || []).each do | type , attribute |
      # Look up the attribute if the person_attribute_id is set  

      #person_attribute_id = person_attribute[:person_attribute_id].to_i rescue nil    
      @person_attribute = nil #PersonAttribute.find(person_attribute_id) unless person_attribute_id.blank?
      # Create or update

      if not @person_attribute.blank?
        @patient_identifier.update_attributes(person_attribute)      
      else
        case type
          when 'agrees_to_be_visited_for_TB_therapy'
            @person_attribute = @patient.person.person_attributes.create(
            :person_attribute_type_id => PersonAttributeType.find_by_name("Agrees to be visited at home for TB therapy").person_attribute_type_id,
            :value => attribute)
          when 'agrees_phone_text_for_TB_therapy'
            @person_attribute = @patient.person.person_attributes.create(
            :person_attribute_type_id => PersonAttributeType.find_by_name("Agrees to phone text for TB therapy").person_attribute_type_id,
            :value => attribute)
        end
      end
    end

    # if params['encounter']['encounter_type_name'] == "APPOINTMENT"
    #  redirect_to "/patients/treatment_dashboard/#{@patient.id}" and return
    # else
      # Go to the dashboard if this is a non-encounter
      # redirect_to "/patients/show/#{@patient.id}" unless params[:encounter]
      # redirect_to next_task(@patient)
    # end

    # Go to the next task in the workflow (or dashboard)
    # only redirect to next task if location parameter has not been provided
    unless params[:location]
    #find a way of printing the lab_orders labels
     if params['encounter']['encounter_type_name'] == "LAB ORDERS"
       redirect_to"/patients/print_lab_orders/?patient_id=#{@patient.id}"
     elsif params['encounter']['encounter_type_name'] == "TB suspect source of referral" && !params[:gender].empty? && !params[:family_name].empty? && !params[:given_name].empty?
       redirect_to"/encounters/new/tb_suspect_source_of_referral/?patient_id=#{@patient.id}&gender=#{params[:gender]}&family_name=#{params[:family_name]}&given_name=#{params[:given_name]}"
     else
      if params['encounter']['encounter_type_name'].to_s.upcase == "APPOINTMENT" && !params[:report_url].nil? && !params[:report_url].match(/report/).nil?
         redirect_to  params[:report_url].to_s and return
      end
      redirect_to next_task(@patient)
     end
    else
      if params[:voided]
        encounter.void(params[:void_reason],
                       params[:date_voided],
                       params[:voided_by])
      end
      #made restful the default due to time
      render :text => encounter.encounter_id.to_s and return
      #return encounter.id.to_s  # support non-RESTful creation of encounters
    end
  end

	def new	
		@patient = Patient.find(params[:patient_id] || session[:patient_id])
		@patient_bean = PatientService.get_patient(@patient.person)
		session_date = session[:datetime].to_date rescue Date.today

		if session[:datetime]
			@retrospective = true 
		else
			@retrospective = false
		end

		@current_height = PatientService.get_patient_attribute_value(@patient, "current_height")
		@min_weight = PatientService.get_patient_attribute_value(@patient, "min_weight")
        @max_weight = PatientService.get_patient_attribute_value(@patient, "max_weight")
        @min_height = PatientService.get_patient_attribute_value(@patient, "min_height")
        @max_height = PatientService.get_patient_attribute_value(@patient, "max_height")
        @given_arvs_before = given_arvs_before(@patient)
        @current_encounters = @patient.encounters.find_by_date(session_date)   
        @previous_tb_visit = previous_tb_visit(@patient.id)
        @is_patient_pregnant_value = nil
        @is_patient_breast_feeding_value = nil
        @currently_using_family_planning_methods = nil
        @transfer_in_TB_registration_number = get_todays_observation_answer_for_encounter(@patient.id, "TB_INITIAL", "TB registration number")
        @referred_to_htc = nil
        @family_planning_methods = []

        if 'tb_reception'.upcase == (params[:encounter_type].upcase rescue '')
            @phone_numbers = PatientService.phone_numbers(Person.find(params[:patient_id]))
        end
        
        if 'ART_VISIT' == (params[:encounter_type].upcase rescue '')
            session_date = session[:datetime].to_date rescue Date.today

            @allergic_to_sulphur = Observation.find(Observation.find(:first,                   
                            :order => "obs_datetime DESC,date_created DESC",            
                            :conditions => ["person_id = ? AND concept_id = ? 
                            AND DATE(obs_datetime) = ?",@patient.id,
                            ConceptName.find_by_name("Allergic to sulphur").concept_id,session_date])).to_s.strip.squish rescue ''

            @obs_ans = Observation.find(Observation.find(:first,                   
                            :order => "obs_datetime DESC,date_created DESC",            
                            :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ?",
                            @patient.id,ConceptName.find_by_name("Prescribe drugs").concept_id,session_date])).to_s.strip.squish rescue ''        
        
        end
        
        if (params[:encounter_type].upcase rescue '') == 'UPDATE HIV STATUS'
            @referred_to_htc = get_todays_observation_answer_for_encounter(@patient.id, "UPDATE HIV STATUS", "Refer to HTC")
        end

		@given_lab_results = Encounter.find(:last,
			:order => "encounter_datetime DESC,date_created DESC",
			:conditions =>["encounter_type = ? and patient_id = ?",
				EncounterType.find_by_name("GIVE LAB RESULTS").id,@patient.id]).observations.map{|o|
				o.answer_string if o.to_s.include?("Laboratory results given to patient")} rescue nil

		@transfer_to = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
			EncounterType.find_by_name("TB VISIT").id,@patient.id]).observations.map{|o|
				o.answer_string if o.to_s.include?("Transfer out to")} rescue nil

		@recent_sputum_results = PatientService.recent_sputum_results(@patient.id) rescue nil
    	@recent_sputum_submissions = PatientService.recent_sputum_submissions(@patient_id) rescue nil
		@continue_treatment_at_site = []
		Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ? AND DATE(encounter_datetime) = ?",
		EncounterType.find_by_name("TB CLINIC VISIT").id,
		@patient.id,session_date.to_date]).observations.map{|o| @continue_treatment_at_site << o.answer_string if o.to_s.include?("Continue treatment")} rescue nil

		@patient_has_closed_TB_program_at_current_location = PatientProgram.find(:all,:conditions =>
			["voided = 0 AND patient_id = ? AND location_id = ? AND (program_id = ? OR program_id = ?)", @patient.id, Location.current_health_center.id, Program.find_by_name('TB PROGRAM').id, Program.find_by_name('MDR-TB PROGRAM').id]).last.closed? rescue true

		if (params[:encounter_type].upcase rescue '') == 'IPT CONTACT PERSON'
			@contacts_ipt = []
						
			@ipt_contacts_ = @patient.tb_contacts.collect{|person| person unless PatientService.get_patient(person).age > 6}.compact rescue []
			@ipt_contacts.each do | person |
				@contacts_ipt << PatientService.get_patient(person)
			end
		end
		
		@select_options = select_options
		@months_since_last_hiv_test = PatientService.months_since_last_hiv_test(@patient.id)
		@current_user_role = self.current_user_role
		@tb_patient = is_tb_patient(@patient)
		@art_patient = PatientService.art_patient?(@patient)
		@recent_lab_results = patient_recent_lab_results(@patient.id)
		@number_of_days_to_add_to_next_appointment_date = number_of_days_to_add_to_next_appointment_date(@patient, session[:datetime] || Date.today)
		@drug_given_before = PatientService.drug_given_before(@patient, session[:datetime])

		use_regimen_short_names = CoreService.get_global_property_value("use_regimen_short_names") rescue "false"
		show_other_regimen = ("show_other_regimen") rescue 'false'

		@answer_array = arv_regimen_answers(:patient => @patient,
			:use_short_names    => use_regimen_short_names == "true",
			:show_other_regimen => show_other_regimen      == "true")

		hiv_program = Program.find_by_name('HIV Program')
		@answer_array = MedicationService.regimen_options(hiv_program.regimens, @patient_bean.age)
		@answer_array += [['Other', 'Other'], ['Unknown', 'Unknown']]

		@hiv_status = PatientService.patient_hiv_status(@patient)
		@hiv_test_date = PatientService.hiv_test_date(@patient.id)
#raise @hiv_test_date.to_s
		@lab_activities = lab_activities
		# @tb_classification = [["Pulmonary TB","PULMONARY TB"],["Extra Pulmonary TB","EXTRA PULMONARY TB"]]
		@tb_patient_category = [["New","NEW"], ["Relapse","RELAPSE"], ["Retreatment after default","RETREATMENT AFTER DEFAULT"], ["Fail","FAIL"], ["Other","OTHER"]]
		@sputum_visual_appearance = [['Muco-purulent','MUCO-PURULENT'],['Blood-stained','BLOOD-STAINED'],['Saliva','SALIVA']]

		@sputum_results = [['Negative', 'NEGATIVE'], ['Scanty', 'SCANTY'], ['1+', 'Weakly positive'], ['2+', 'Moderately positive'], ['3+', 'Strongly positive']]

		@sputum_orders = Hash.new()
		@sputum_submission_waiting_results = Hash.new()
		@sputum_results_not_given = Hash.new()
		@art_first_visit = is_first_art_visit(@patient.id)
		@tb_first_registration = is_first_tb_registration(@patient.id)
		@tb_programs_state = uncompleted_tb_programs_status(@patient)
		@had_tb_treatment_before = ever_received_tb_treatment(@patient.id)
		@any_previous_tb_programs = any_previous_tb_programs(@patient.id)

		PatientService.sputum_orders_without_submission(@patient.id).each { | order | 
			@sputum_orders[order.accession_number] = Concept.find(order.value_coded).fullname rescue order.value_text
		}
		
		sputum_submissons_with_no_results(@patient.id).each{|order| @sputum_submission_waiting_results[order.accession_number] = Concept.find(order.value_coded).fullname rescue order.value_text}
		sputum_results_not_given(@patient.id).each{|order| @sputum_results_not_given[order.accession_number] = Concept.find(order.value_coded).fullname rescue order.value_text}

		@tb_status = recent_lab_results(@patient.id, session_date)
    	# use @patient_tb_status  for the tb_status moved from the patient model
    	@patient_tb_status = PatientService.patient_tb_status(@patient)
		@patient_is_transfer_in = is_transfer_in(@patient)
		@patient_transfer_in_date = get_transfer_in_date(@patient)
		@patient_is_child_bearing_female = is_child_bearing_female(@patient)
    	@cell_number = @patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue ''

    	@tb_symptoms = []

		if (params[:encounter_type].upcase rescue '') == 'TB_INITIAL'
			tb_program = Program.find_by_name('TB Program')
			@tb_regimen_array = MedicationService.regimen_options(tb_program.regimens, @patient_bean.age)
			tb_program = Program.find_by_name('MDR-TB Program')
			@tb_regimen_array += MedicationService.regimen_options(tb_program.regimens, @patient_bean.age)
			@tb_regimen_array += [['Other', 'Other'], ['Unknown', 'Unknown']]
		end

		if (params[:encounter_type].upcase rescue '') == 'TB_VISIT'
		  @current_encounters.reverse.each do |enc|
		     enc.observations.each do |o|
		       @tb_symptoms << o.answer_string.strip if o.to_s.include?("TB symptoms") rescue nil
		     end
		   end
		end

		@location_transferred_to = []
		if (params[:encounter_type].upcase rescue '') == 'APPOINTMENT'
		  @old_appointment = nil
		  @report_url = nil
		  @report_url =  params[:report_url]  and @old_appointment = params[:old_appointment] if !params[:report_url].nil?
		  @current_encounters.reverse.each do |enc|
		     enc.observations.each do |o|
		       @location_transferred_to << o.to_s_location_name.strip if o.to_s.include?("Transfer out to") rescue nil
		     end
		   end
		end

		@tb_classification = nil
		@eptb_classification = nil
		@tb_type = nil

		@patients = nil
		
		if (params[:encounter_type].upcase rescue '') == "SOURCE_OF_REFERRAL"
			people = PatientService.person_search(params)
			@patients = []
			people.each do | person |
				patient = PatientService.get_patient(person)
				@patients << patient
			end
		end

		if (params[:encounter_type].upcase rescue '') == 'TB_REGISTRATION'

			tb_clinic_visit_obs = Encounter.find(:first,:order => "encounter_datetime DESC",
				:conditions => ["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
				session_date, @patient.id, EncounterType.find_by_name('TB CLINIC VISIT').id]).observations rescue []

			(tb_clinic_visit_obs || []).each do | obs | 
				if (obs.concept_id == (Concept.find_by_name('TB type').concept_id rescue nil) || obs.concept_id == (Concept.find_by_name('TB classification').concept_id rescue nil) || 	obs.concept_id == (Concept.find_by_name('EPTB classification').concept_id rescue nil))
					@tb_classification = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name rescue Concept.find(obs.value_coded).fullname if Concept.find_by_name('TB classification').concept_id
					@eptb_classification = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name rescue Concept.find(obs.value_coded).fullname if obs.concept_id == Concept.find_by_name('EPTB classification').concept_id
					@tb_type = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name rescue Concept.find(obs.value_coded).fullname if obs.concept_id == Concept.find_by_name('TB type').concept_id
 				end
			end
			#raise @tb_classification.to_s

		end

        if  ['ART_VISIT', 'TB_VISIT', 'HIV_STAGING'].include?((params[:encounter_type].upcase rescue ''))
			@local_tb_dot_sites_tag = tb_dot_sites_tag 
			for encounter in @current_encounters.reverse do
				if encounter.name.humanize.include?('Hiv staging') || encounter.name.humanize.include?('Tb visit') || encounter.name.humanize.include?('Art visit') 
					encounter = Encounter.find(encounter.id, :include => [:observations])
					for obs in encounter.observations do
						if obs.concept_id == ConceptName.find_by_name("IS PATIENT PREGNANT?").concept_id
							@is_patient_pregnant_value = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}"
						end

						if obs.concept_id == ConceptName.find_by_name("IS PATIENT BREAST FEEDING?").concept_id
							@is_patient_breast_feeding_value = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}"
						end
					end

					if encounter.name.humanize.include?('Tb visit') || encounter.name.humanize.include?('Art visit')
						encounter = Encounter.find(encounter.id, :include => [:observations])
						for obs in encounter.observations do
							if obs.concept_id == ConceptName.find_by_name("CURRENTLY USING FAMILY PLANNING METHOD").concept_id
								@currently_using_family_planning_methods = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish
							end

							if obs.concept_id == ConceptName.find_by_name("FAMILY PLANNING METHOD").concept_id
								@family_planning_methods << "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish
							end
						end
					end
				end
			end
        end

		if (params[:encounter_type].upcase rescue '') == 'HIV_STAGING'
			if @patient_bean.age > 14 
				@who_stage_i = concept_set('WHO STAGE I ADULT AND PEDS') + concept_set('WHO STAGE I ADULT')
				@who_stage_ii = concept_set('WHO STAGE II ADULT AND PEDS') + concept_set('WHO STAGE II ADULT')
				@who_stage_iii = concept_set('WHO STAGE III ADULT AND PEDS') + concept_set('WHO STAGE III ADULT')
				@who_stage_iv = concept_set('WHO STAGE IV ADULT AND PEDS') + concept_set('WHO STAGE IV ADULT')

				if CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true"
					@not_explicitly_asked = concept_set('WHO Stage defining conditions not explicitly asked adult')
				end
			else
				@who_stage_i = concept_set('WHO STAGE I ADULT AND PEDS') + concept_set('WHO STAGE I PEDS')
				@who_stage_ii = concept_set('WHO STAGE II ADULT AND PEDS') + concept_set('WHO STAGE II PEDS')
				@who_stage_iii = concept_set('WHO STAGE III ADULT AND PEDS') + concept_set('WHO STAGE III PEDS')
				@who_stage_iv = concept_set('WHO STAGE IV ADULT AND PEDS') + concept_set('WHO STAGE IV PEDS')
				if CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true"
					@not_explicitly_asked = concept_set('WHO Stage defining conditions not explicitly asked peds')
				end
			end

			if !@retrospective
				@who_stage_i = @who_stage_i - concept_set('Unspecified Staging Conditions')
				@who_stage_ii = @who_stage_ii - concept_set('Unspecified Staging Conditions')
				@who_stage_iii = @who_stage_iii - concept_set('Unspecified Staging Conditions')
				@who_stage_iv = @who_stage_iv - concept_set('Unspecified Staging Conditions') - concept_set('Calculated WHO HIV staging conditions')
			end
			
			if @tb_status == true && @hiv_status != 'Negative'
		    	tb_hiv_exclusions = [['Pulmonary tuberculosis (current)', 'Pulmonary tuberculosis (current)'], 
					['Tuberculosis (PTB or EPTB) within the last 2 years', 'Tuberculosis (PTB or EPTB) within the last 2 years']]
				@who_stage_iii = @who_stage_iii - tb_hiv_exclusions
			end
  			
			@confirmatory_hiv_test_type = Observation.question("CONFIRMATORY HIV TEST TYPE").first(:conditions => {:person_id => @patient.person}, :include => :answer_concept_name).answer_concept_name.name rescue 'UNKNOWN'
			#raise concept_set('WHO Stage defining conditions not explicitly asked adult').to_yaml
			#raise CoreService.get_global_property_value('use.extended.staging.questions').to_s
			#raise @not_explicitly_asked.to_yaml
			#raise concept_set('PRESUMED SEVERE HIV CRITERIA IN INFANTS').to_yaml
		end

		redirect_to "/" and return unless @patient

		redirect_to next_task(@patient) and return unless params[:encounter_type]

		redirect_to :action => :create, 'encounter[encounter_type_name]' => params[:encounter_type].upcase, 'encounter[patient_id]' => @patient.id and return if ['registration'].include?(params[:encounter_type])
		
		if (params[:encounter_type].upcase rescue '') == 'HIV_STAGING' and  (CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true" rescue false)
			render :template => 'encounters/extended_hiv_staging'
		else
			render :action => params[:encounter_type] if params[:encounter_type]
		end
		
	end

	def current_user_role
		@role = User.current_user.user_roles.map{|r|r.role}
		return @role
	end

	def diagnoses
		search_string = (params[:search_string] || '').upcase
		filter_list = params[:filter_list].split(/, */) rescue []
		outpatient_diagnosis = ConceptName.find_by_name("DIAGNOSIS").concept
		diagnosis_concepts = ConceptClass.find_by_name("Diagnosis", :include => {:concepts => :name}).concepts rescue []    
		# TODO Need to check a global property for which concept set to limit things to

		#diagnosis_concept_set = ConceptName.find_by_name('MALAWI NATIONAL DIAGNOSIS').concept This should be used when the concept becames available
		diagnosis_concept_set = ConceptName.find_by_name('MALAWI ART SYMPTOM SET').concept
		diagnosis_concepts = Concept.find(:all, :joins => :concept_sets, :conditions => ['concept_set = ?', diagnosis_concept_set.id])

		valid_answers = diagnosis_concepts.map{|concept| 
			name = concept.fullname rescue nil
			name.match(search_string) ? name : nil rescue nil
		}.compact
		previous_answers = []
		# TODO Need to check global property to find out if we want previous answers or not (right now we)
		previous_answers = Observation.find_most_common(outpatient_diagnosis, search_string)
		@suggested_answers = (previous_answers + valid_answers).reject{|answer| filter_list.include?(answer) }.uniq[0..10] 
		@suggested_answers = @suggested_answers - params[:search_filter].split(',') rescue @suggested_answers
		render :text => "<li>" + @suggested_answers.join("</li><li>") + "</li>"
	end

	def treatment
		search_string = (params[:search_string] || '').upcase
		filter_list = params[:filter_list].split(/, */) rescue []
		valid_answers = []
		unless search_string.blank?
			drugs = Drug.find(:all, :conditions => ["name LIKE ?", '%' + search_string + '%'])
			valid_answers = drugs.map {|drug| drug.name.upcase }
		end
		treatment = ConceptName.find_by_name("TREATMENT").concept
		previous_answers = Observation.find_most_common(treatment, search_string)
		suggested_answers = (previous_answers + valid_answers).reject{|answer| filter_list.include?(answer) }.uniq[0..10] 
		render :text => "<li>" + suggested_answers.join("</li><li>") + "</li>"
	end

	def locations
		search_string = (params[:search_string] || 'neno').upcase
		filter_list = params[:filter_list].split(/, */) rescue []    
		locations =  Location.find(:all, :select =>'name', :conditions => ["name LIKE ?", '%' + search_string + '%'])
		render :text => "<li>" + locations.map{|location| location.name }.join("</li><li>") + "</li>"
	end

	def observations
		# We could eventually include more here, maybe using a scope with includes
		@encounter = Encounter.find(params[:id], :include => [:observations])
		render :layout => false
	end

	def void
		@encounter = Encounter.find(params[:id])
		@encounter.void
		head :ok
	end

	# List ARV Regimens as options for a select HTML element
	# <tt>options</tt> is a hash which should have the following keys and values
	#
	# <tt>patient</tt>: a Patient whose regimens will be listed
	# <tt>use_short_names</tt>: true, false (whether to use concept short names or
	#  names)
	#
	def arv_regimen_answers(options = {})
		answer_array = Array.new
		regimen_types = ['FIRST LINE ANTIRETROVIRAL REGIMEN', 
			'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN',
			'SECOND LINE ANTIRETROVIRAL REGIMEN'
		]

		regimen_types.collect{|regimen_type|
			Concept.find_by_name(regimen_type).concept_members.flatten.collect{|member|
				next if member.concept.fullname.include?("Triomune Baby") and !PatientService.patient_is_child?(options[:patient])
				next if member.concept.fullname.include?("Triomune Junior") and !PatientService.patient_is_child?(options[:patient])
				if options[:use_short_names]
					include_fixed = member.concept.fullname.match("(fixed)")
					answer_array << [member.concept.shortname, member.concept_id] unless include_fixed
					answer_array << ["#{member.concept.shortname} (fixed)", member.concept_id] if include_fixed
					member.concept.shortname
				else
					answer_array << [member.concept.fullname.titleize, member.concept_id] unless member.concept.fullname.include?("+")
					answer_array << [member.concept.fullname, member.concept_id] if member.concept.fullname.include?("+")
				end
			}
		}

		if options[:show_other_regimen]
		  answer_array << "Other" if !answer_array.blank?
		end
		answer_array

		# raise answer_array.inspect
	end

	def lab
		@patient = Patient.find(params[:encounter][:patient_id])
		encounter_type = params[:observations][0][:value_coded_or_text] 
		redirect_to "/encounters/new/#{encounter_type}?patient_id=#{@patient.id}"
	end

	def lab_orders
		@lab_orders = select_options['lab_orders'][params['sample']].collect{|order| order}
		render :text => '<li></li><li>' + @lab_orders.join('</li><li>') + '</li>'
	end

	def give_drugs
		@patient = Patient.find(params[:patient_id] || session[:patient_id])
		 #@prescriptions = @patient.orders.current.prescriptions.all
		type = EncounterType.find_by_name('TREATMENT')
		session_date = session[:datetime].to_date rescue Date.today
		@prescriptions = Order.find(:all,
				         :joins => "INNER JOIN encounter e USING (encounter_id)",
				         :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
				         type.id,@patient.id,session_date])
		@historical = @patient.orders.historical.prescriptions.all
		@restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		@restricted.each do |restriction|
			@prescriptions = restriction.filter_orders(@prescriptions)
			@historical = restriction.filter_orders(@historical)
		end
		#render :layout => "menu" 
		render :template => 'dashboards/treatment_dashboard', :layout => false
	end

	def is_first_art_visit(patient_id)
		session_date = session[:datetime].to_date rescue Date.today
		art_encounter = Encounter.find(:first,:conditions =>["voided = 0 AND patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) < ?",
				patient_id, EncounterType.find_by_name('ART_INITIAL').id, session_date ]) rescue nil
		return true if art_encounter.nil?
		return false
	end

	def is_first_tb_registration(patient_id)
		session_date = session[:datetime].to_date rescue Date.today
		tb_registration = Encounter.find(:first,
			:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) < ?",
			patient_id,EncounterType.find_by_name('TB REGISTRATION').id, session_date]) rescue nil

		return true if tb_registration.nil?
		return false
	end

	def uncompleted_tb_programs_status(patient)

		tb_program_state = nil

		tb_programs = patient.patient_programs.not_completed.in_programs('MDR-TB program') 
		tb_programs = patient.patient_programs.not_completed.in_programs('XDR-TB program') if tb_programs.blank?
		tb_programs = patient.patient_programs.not_completed.in_programs('TB PROGRAM') if tb_programs.blank?

		unless tb_programs.blank?
			tb_programs.each{|program|
				tb_status_state = program.patient_states.last.program_workflow_state.concept.fullname
			}
		end

		return tb_program_state
	end

	def recent_lab_results(patient_id, session_date = Date.today)
		sputum_concept_names = ["AAFB(1st) results", "AAFB(2nd) results", "AAFB(3rd) results", "Culture(1st) Results", "Culture-2 Results"]
		sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id)

		lab_results = Encounter.find(:last,:conditions =>["encounter_type = ? AND patient_id = ? AND DATE(encounter_datetime) >= ?",
			EncounterType.find_by_name("LAB RESULTS").id, patient_id, (session_date.to_date - 3.month).strftime('%Y-%m-%d 00:00:00')])
				            
		positive_result = false                  

		results = lab_results.observations.map{|o| o if sputum_concept_ids.include?(o.concept_id)} rescue []

		results.each do |result|
			concept_name = Concept.find(result.value_coded).fullname.upcase rescue 'NEGATIVE'
			if not ((concept_name).include? 'NEGATIVE')
				positive_result = true
			end
		end

		return positive_result
	end

  def select_options
    select_options = {
     'reason_for_tb_clinic_visit' => [
        ['',''],
        ['Clinical review (Children, Smear-, HIV+)','CLINICAL REVIEW'],
        ['Smear Positive (HIV-)','SMEAR POSITIVE'],
        ['X-ray result interpretation','X-RAY RESULT INTERPRETATION']
      ],
     'tb_clinic_visit_type' => [
        ['',''],
        ['Lab analysis','Lab follow-up'],
        ['Follow-up','Follow-up'],
        ['Clinical review (Clinician visit)','Clinical review']
      ],
     'family_planning_methods' => [
       ['',''],
       ['Oral contraceptive pills', 'ORAL CONTRACEPTIVE PILLS'],
       ['Depo-Provera', 'DEPO-PROVERA'],
       ['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
       ['Contraceptive implant', 'CONTRACEPTIVE IMPLANT'],
       ['Male condoms', 'MALE CONDOMS'],
       ['Female condoms', 'FEMALE CONDOMS'],
       ['Rhythm method', 'RYTHM METHOD'],
       ['Withdrawal', 'WITHDRAWAL'],
       ['Abstinence', 'ABSTINENCE'],
       ['Tubal ligation', 'TUBAL LIGATION'],
       ['Vasectomy', 'VASECTOMY']
      ],
     'male_family_planning_methods' => [
       ['',''],
       ['Male condoms', 'MALE CONDOMS'],
       ['Withdrawal', 'WITHDRAWAL'],
       ['Rhythm method', 'RYTHM METHOD'],
       ['Abstinence', 'ABSTINENCE'],
       ['Vasectomy', 'VASECTOMY'],
       ['Other','OTHER']
      ],
     'female_family_planning_methods' => [
       ['',''],
       ['Oral contraceptive pills', 'ORAL CONTRACEPTIVE PILLS'],
       ['Depo-Provera', 'DEPO-PROVERA'],
       ['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
       ['Contraceptive implant', 'CONTRACEPTIVE IMPLANT'],
       ['Female condoms', 'FEMALE CONDOMS'],
       ['Withdrawal', 'WITHDRAWAL'],
       ['Rhythm method', 'RYTHM METHOD'],
       ['Abstinence', 'ABSTINENCE'],
       ['Tubal ligation', 'TUBAL LIGATION'],
       ['Emergency contraception', 'EMERGENCY CONTRACEPTION'],
       ['Other','OTHER']
      ],
     'drug_list' => [
          ['',''],
          ["Rifampicin Isoniazid Pyrazinamide and Ethambutol", "RHEZ (RIF, INH, Ethambutol and Pyrazinamide tab)"],
          ["Rifampicin Isoniazid and Ethambutol", "RHE (Rifampicin Isoniazid and Ethambutol -1-1-mg t"],
          ["Rifampicin and Isoniazid", "RH (Rifampin and Isoniazid tablet)"],
          ["Stavudine Lamivudine and Nevirapine", "D4T+3TC+NVP"],
          ["Stavudine Lamivudine + Stavudine Lamivudine and Nevirapine", "D4T+3TC/D4T+3TC+NVP"],
          ["Zidovudine Lamivudine and Nevirapine", "AZT+3TC+NVP"]
      ],
        'presc_time_period' => [
          ["",""],
          ["1 month", "30"],
          ["2 months", "60"],
          ["3 months", "90"],
          ["4 months", "120"],
          ["5 months", "150"],
          ["6 months", "180"],
          ["7 months", "210"],
          ["8 months", "240"]
      ],
        'continue_treatment' => [
          ["",""],
          ["Yes", "YES"],
          ["DHO DOT site","DHO DOT SITE"],
          ["Transfer Out", "TRANSFER OUT"]
      ],
        'hiv_status' => [
          ['',''],
          ['Negative','NEGATIVE'],
          ['Positive','POSITIVE'],
          ['Unknown','UNKNOWN']
      ],
      'who_stage1' => [
        ['',''],
        ['Asymptomatic','ASYMPTOMATIC'],
        ['Persistent generalised lymphadenopathy','PERSISTENT GENERALISED LYMPHADENOPATHY'],
        ['Unspecified stage 1 condition','UNSPECIFIED STAGE 1 CONDITION']
      ],
      'who_stage2' => [
        ['',''],
        ['Unspecified stage 2 condition','UNSPECIFIED STAGE 2 CONDITION'],
        ['Angular cheilitis','ANGULAR CHEILITIS'],
        ['Popular pruritic eruptions / Fungal nail infections','POPULAR PRURITIC ERUPTIONS / FUNGAL NAIL INFECTIONS']
      ],
      'who_stage3' => [
        ['',''],
        ['Oral candidiasis','ORAL CANDIDIASIS'],
        ['Oral hairly leukoplakia','ORAL HAIRLY LEUKOPLAKIA'],
        ['Pulmonary tuberculosis','PULMONARY TUBERCULOSIS'],
        ['Unspecified stage 3 condition','UNSPECIFIED STAGE 3 CONDITION']
      ],
      'who_stage4' => [
        ['',''],
        ['Toxaplasmosis of the brain','TOXAPLASMOSIS OF THE BRAIN'],
        ["Kaposi's Sarcoma","KAPOSI'S SARCOMA"],
        ['Unspecified stage 4 condition','UNSPECIFIED STAGE 4 CONDITION'],
        ['HIV encephalopathy','HIV ENCEPHALOPATHY']
      ],
      'tb_xray_interpretation' => [
        ['',''],
        ['Consistent of TB','Consistent of TB'],
        ['Not Consistent of TB','Not Consistent of TB']
      ],
      'lab_orders' =>{
        "Blood" => ["Full blood count", "Malaria parasite", "Group & cross match", "Urea & Electrolytes", "CD4 count", "Resistance",
            "Viral Load", "Cryptococcal Antigen", "Lactate", "Fasting blood sugar", "Random blood sugar", "Sugar profile",
            "Liver function test", "Hepatitis test", "Sickling test", "ESR", "Culture & sensitivity", "Widal test", "ELISA",
            "ASO titre", "Rheumatoid factor", "Cholesterol", "Triglycerides", "Calcium", "Creatinine", "VDRL", "Direct Coombs",
            "Indirect Coombs", "Blood Test NOS"],
        "CSF" => ["Full CSF analysis", "Indian ink", "Protein & sugar", "White cell count", "Culture & sensitivity"],
        "Urine" => ["Urine microscopy", "Urinanalysis", "Culture & sensitivity"],
        "Aspirate" => ["Full aspirate analysis"],
        "Stool" => ["Full stool analysis", "Culture & sensitivity"],
        "Sputum-AAFB" => ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)"],
        "Sputum-Culture" => ["Culture(1st)", "Culture(2nd)"],
        "Swab" => ["Microscopy", "Culture & sensitivity"]
      },
      'tb_symptoms_short' => [
        ['',''],
        ["Bloody cough", "Hemoptysis"],
        ["Chest pain", "Chest pain"],
        ["Cough", "Cough lasting more than three weeks"],
        ["Fatigue", "Fatigue"],
        ["Fever", "Relapsing fever"],
        ["Loss of appetite", "Loss of appetite"],
        ["Night sweats","Night sweats"],
        ["Shortness of breath", "Shortness of breath"],
        ["Weight loss", "Weight loss"],
        ["Other", "Other"]
      ],
      'tb_symptoms_all' => [
        ['',''],
        ["Bloody cough", "Hemoptysis"],
        ["Bronchial breathing", "Bronchial breathing"],
        ["Crackles", "Crackles"],
        ["Cough", "Cough lasting more than three weeks"],
        ["Failure to thrive", "Failure to thrive"],
        ["Fatigue", "Fatigue"],
        ["Fever", "Relapsing fever"],
        ["Loss of appetite", "Loss of appetite"],
        ["Meningitis", "Meningitis"],
        ["Night sweats","Night sweats"],
        ["Peripheral neuropathy", "Peripheral neuropathy"],
        ["Shortness of breath", "Shortness of breath"],
        ["Weight loss", "Weight loss"],
        ["Other", "Other"]
      ],
      'drug_related_side_effects' => [
        ['',''],
        ["Confusion", "Confusion"],
        ["Deafness", "Deafness"],
        ["Dizziness", "Dizziness"],
        ["Peripheral neuropathy","Peripheral neuropathy"],
        ["Skin itching/purpura", "Skin itching"],
        ["Visual impairment", "Visual impairment"],
        ["Vomiting", "Vomiting"],
        ["Yellow eyes", "Jaundice"],
        ["Other", "Other"]
      ],
      'tb_patient_categories' => [
        ['',''],
        ["New", "New patient"],
        ["Failure", "Failed - TB"],
        ["Relapse", "Relapse MDR-TB patient"],
        ["Retreatment after default", "Treatment after default MDR-TB patient"],
        ["Other", "Other"]
      ],
      'duration_of_current_cough' => [
        ['',''],
        ["Less than 1 week", "Less than one week"],
        ["1 Week", "1 week"],
        ["2 Weeks", "2 weeks"],
        ["3 Weeks", "3 weeks"],
        ["4 Weeks", "4 weeks"],
        ["More than 4 Weeks", "More than 4 weeks"],
        ["Unknown", "Unknown"]
      ],
      'eptb_classification'=> [
        ['',''],
        ['Pulmonary effusion', 'Pulmonary effusion'],
        ['Lymphadenopathy', 'Lymphadenopathy'],
        ['Pericardial effusion', 'Pericardial effusion'],
        ['Ascites', 'Ascites'],
        ['Spinal disease', 'Spinal disease'],
        ['Meningitis','Meningitis'],
        ['Other', 'Other']
      ],
      'tb_types' => [
        ['',''],
        ['Susceptible', 'Susceptible to tuberculosis drug'],
        ['Multi-drug resistant (MDR)', 'Multi-drug resistant tuberculosis'],
        ['Extreme drug resistant (XDR)', 'Extreme drug resistant tuberculosis']
      ],
      'tb_classification' => [
        ['',''],
        ['Pulmonary tuberculosis (PTB)', 'Pulmonary tuberculosis'],
        ['Extrapulmonary tuberculosis (EPTB)', 'Extrapulmonary tuberculosis (EPTB)']
      ]
    }
  end

  def ever_received_tb_treatment(patient_id)
		encounters = Encounter.find(:all,:conditions =>["patient_id = ? AND encounter_type = ?",
				patient_id, EncounterType.find_by_name('TB_INITIAL').id],
        :include => [:observations],:order =>'encounter_datetime ASC') rescue nil

    tb_treatment_value = ''
    unless encounters.nil?
      encounters.each { |encounter|
        encounter.observations.each { |observation|
           if observation.concept_id == ConceptName.find_by_name("Ever received TB treatment").concept_id
              tb_treatment_value = ConceptName.find_by_concept_id(observation.value_coded).name
           end
        }
      }
    end
		return true if tb_treatment_value == "Yes"
		return false
	end

    def any_previous_tb_programs(patient_id)
        @tb_programs = ''
        patient_programs = PatientProgram.find_all_by_patient_id(patient_id)

        unless patient_programs.blank?
          patient_programs.each{ |patient_program|
            if patient_program.program_id == Program.find_by_name("MDR-TB program").program_id ||
               patient_program.program_id == Program.find_by_name("TB PROGRAM").program_id
              @tb_programs = true
              break
            end
          }
        end
	    
	    return false if @tb_programs.blank?
        return true
    end
	
	def previous_tb_visit(patient_id)
		session_date = session[:datetime].to_date rescue Date.today
        encounter = Encounter.find(:all, :conditions=>["patient_id = ? \
                    AND encounter_type = ? AND DATE(encounter_datetime) < ? ", patient_id, \
                    EncounterType.find_by_name("TB VISIT").id, session_date]).last rescue nil
        @date = encounter.encounter_datetime.to_date rescue nil
        previous_visit_obs = []

        if !encounter.nil?
            for obs in encounter.observations do
                    previous_visit_obs << "#{(obs.to_s(["short", "order"])).gsub('hiv','HIV').gsub('Hiv','HIV')}".squish
            end
        end
        previous_visit_obs
	end
	
	def get_todays_observation_answer_for_encounter(patient_id, encountertype_name, observation_name)
		session_date = session[:datetime].to_date rescue Date.today
        encounter = Encounter.find(:all, :conditions=>["patient_id = ? \
                    AND encounter_type = ? AND DATE(encounter_datetime) = ? ", patient_id, \
                    EncounterType.find_by_name("#{encountertype_name}").id, session_date]).last rescue nil
        @date = encounter.encounter_datetime.to_date rescue nil
        observation = nil
        if !encounter.nil?
            for obs in encounter.observations do
                if obs.concept_id == ConceptName.find_by_name("#{observation_name}").concept_id
                    observation = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish
                end
            end
        end
        observation
	end

  def lab_activities
    lab_activities = [
      ['Lab Orders', 'lab_orders'],
      ['Sputum Submission', 'sputum_submission'],
      ['Lab Results', 'lab_results'],
    ]
  end

  #originally recent_lab_results. Changed to portray the usage
  def patient_recent_lab_results(patient_id)
   Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("LAB RESULTS").id,patient_id]).observations.map{|o| o } rescue nil
  end

  def sputum_submissons_with_no_results(patient_id)
    sputum_concept_names = ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)", "Culture(1st)", "Culture(2nd)"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id)
    sputums_array = Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? AND (value_coded in (?) OR value_text in (?))", patient_id, ConceptName.find_by_name('Tests ordered').concept_id, sputum_concept_ids, sputum_concept_names], :order => "obs_datetime desc", :limit => 3)

    results_concept_name = ["AAFB(1st) results", "AAFB(2nd) results", "AAFB(3rd) results", "Culture(1st) Results", "Culture-2 Results"]
    sputum_results_id = ConceptName.find(:all, :conditions => ["name IN (?)", results_concept_name ]).map(&:concept_id)

    sputums_array = sputums_array.select { |order|
                       accessor_history = Observation.find(:all, :conditions => ["person_id = ? AND accession_number  = (?) AND voided = 0 AND concept_id IN (?)",  patient_id, order.accession_number, sputum_results_id]);
                       accessor_history.size == 0
                    }
    sputums_array
  end

  def sputum_results_not_given(patient_id)
    PatientService.recent_sputum_results(patient_id).collect{|order| order unless Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ?", patient_id, Concept.find_by_name("Lab test result").concept_id]).map{|o| o.accession_number}.include?(order.accession_number)}.compact
  end

  def is_tb_patient(patient)
    return given_tb_medication_before(patient)
  end

  def given_tb_medication_before(patient)
    patient.orders.each{|order|
      drug_order = order.drug_order
      drug_order_quantity = drug_order.quantity
      if drug_order_quantity == nil
        drug_order_quantity = 0
      end
      next if drug_order == nil
      next unless drug_order_quantity > 0
      return true if MedicationService.tb_medication(drug_order.drug)
    }
    false
  end

  def get_transfer_in_date(patient)
    patient_transfer_in = patient.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
    return patient_transfer_in.each{|datetime| return datetime.obs_datetime  if datetime.obs_datetime}
  end

  def is_transfer_in(patient)
    patient_transfer_in = patient.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
    return false if patient_transfer_in.blank?
    return true
  end

  def is_child_bearing_female(patient)
  	patient_bean = PatientService.get_patient(patient.person)
    (patient_bean.sex == 'Female' && patient_bean.age >= 9 && patient_bean.age <= 45) ? true : false
  end

  def given_arvs_before(patient)
    patient.orders.each{|order|
      drug_order = order.drug_order
      next if drug_order == nil
      next if drug_order.quantity == nil
      next unless drug_order.quantity > 0
      return true if MedicationService.arv(drug_order.drug)
    }
    false
  end

   def number_of_days_to_add_to_next_appointment_date(patient, date = Date.today)
    #because a dispension/pill count can have several drugs,we pick the drug with the lowest pill count
    #and we also make sure the drugs in the pill count/Adherence encounter are the same as the one in Dispension encounter

    concept_id = ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').concept_id
    encounter_type = EncounterType.find_by_name('ART ADHERENCE')
    adherence = Observation.find(:all,
      :joins => 'INNER JOIN encounter USING(encounter_id)',
      :conditions =>["encounter_type = ? AND patient_id = ? AND concept_id = ? AND DATE(encounter_datetime)=?",
        encounter_type.id,patient.id,concept_id,date.to_date],:order => 'encounter_datetime DESC')
    return 0 if adherence.blank?
    concept_id = ConceptName.find_by_name('AMOUNT DISPENSED').concept_id
    encounter_type = EncounterType.find_by_name('DISPENSING')
    drug_dispensed = Observation.find(:all,
      :joins => 'INNER JOIN encounter USING(encounter_id)',
      :conditions =>["encounter_type = ? AND patient_id = ? AND concept_id = ? AND DATE(encounter_datetime)=?",
        encounter_type.id,patient.id,concept_id,date.to_date],:order => 'encounter_datetime DESC')

    #check if what was dispensed is what was counted as remaing pills
    return 0 unless (drug_dispensed.map{| d | d.value_drug } - adherence.map{|a|a.order.drug_order.drug_inventory_id}) == []

    #the folliwing block of code picks the drug with the lowest pill count
    count_drug_count = []
    (adherence).each do | adh |
      unless count_drug_count.blank?
        if adh.value_numeric < count_drug_count[1]
          count_drug_count = [adh.order.drug_order.drug_inventory_id,adh.value_numeric]
        end
      end
      count_drug_count = [adh.order.drug_order.drug_inventory_id,adh.value_numeric] if count_drug_count.blank?
    end

    #from the drug dispensed on that day,we pick the drug "plus it's daily dose" that match the drug with the lowest pill count
    equivalent_daily_dose = 1
    (drug_dispensed).each do | dispensed_drug |
      drug_order = dispensed_drug.order.drug_order
      if count_drug_count[0] == drug_order.drug_inventory_id
        equivalent_daily_dose = drug_order.equivalent_daily_dose
      end
    end
    (count_drug_count[1] / equivalent_daily_dose).to_i
  end

  def new_appointment                                                   
    #render :layout => "menu"                                                    
  end
  
  def update

    @encounter = Encounter.find(params[:encounter_id])
    ActiveRecord::Base.transaction do
      @encounter.void
    end
    
    encounter = Encounter.new(params[:encounter])
    encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank? or encounter.name == 'DIABETES TEST'
    encounter.save

       # saving  of encounter states
    if(params[:complete])
      encounter_state = EncounterState.find(encounter.encounter_id) rescue nil

      if(encounter_state) # update an existing encounter_state
        state =  params[:complete] == "true"? 1 : 0
        EncounterState.update_attributes(:encounter_id => encounter.encounter_id, :state => state)
      else # a new encounter_state
        state =  params[:complete] == "true"? 1 : 0
        EncounterState.create(:encounter_id => encounter.encounter_id, :state => state)
      end
    end

    (params[:observations] || []).each{|observation|
      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
      observation[:encounter_id] = encounter.id
      observation[:obs_datetime] = encounter.encounter_datetime ||= Time.now()
      observation[:person_id] ||= encounter.patient_id
      observation[:concept_name] ||= "OUTPATIENT DIAGNOSIS" if encounter.type.name == "OUTPATIENT DIAGNOSIS"

      # convert values from 'mmol/litre' to 'mg/declitre'
      if(observation[:measurement_unit])
        observation[:value_numeric] = observation[:value_numeric].to_f * 18 if ( observation[:measurement_unit] == "mmol/l")
        observation.delete(:measurement_unit)
      end

      if(observation[:parent_concept_name])
        concept_id = Concept.find_by_name(observation[:parent_concept_name]).id rescue nil
        observation[:obs_group_id] = Observation.find(:first, :conditions=> ['concept_id = ? AND encounter_id = ?',concept_id, encounter.id]).id rescue ""
        observation.delete(:parent_concept_name)
      end

      concept_id = Concept.find_by_name(observation[:concept_name]).id rescue nil
      obs_id = Observation.find(:first, :conditions=> ['concept_id = ? AND encounter_id = ?',concept_id, encounter.id]).id rescue nil

      extracted_value_numerics = observation[:value_numeric]
      if (extracted_value_numerics.class == Array)

        extracted_value_numerics.each do |value_numeric|
          observation[:value_numeric] = value_numeric
          Observation.create(observation)
        end
      else
        Observation.create(observation)
      end
              
    }

    @patient = Patient.find(params[:encounter][:patient_id])

    # redirect to a custom destination page 'next_url'
    #if(params[:next_url])
      redirect_to "/patients/show/#{@patient.patient_id}" and return
    #else
    #  redirect_to next_task(@patient)
    #end

  end

end
