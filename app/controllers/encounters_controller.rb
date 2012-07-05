class EncountersController < GenericEncountersController
	def new
	
		@patient = Patient.find(params[:patient_id] || session[:patient_id])
		@patient_bean = PatientService.get_patient(@patient.person)
		session_date = session[:datetime].to_date rescue Date.today

		if session[:datetime]
			@retrospective = true 
		else
			@retrospective = false
		end
		@current_height = PatientService.get_patient_attribute_value(@patient, "current_height", session_date)

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
       
        if 'HIV_CLINIC_CONSULTATION' == (params[:encounter_type].upcase rescue '') || 'ART_ADHERENCE' == (params[:encounter_type].upcase rescue '')
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

    	@recent_sputum_submissions = PatientService.recent_sputum_submissions(@patient.id) 	

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
		
		if (params[:encounter_type].upcase rescue '') == 'APPOINTMENT'
			@todays_date = session_date
			logger.info('========================== Suggesting appointment date =================================== @ '  + Time.now.to_s)
			@suggested_appointment_date = suggest_appointment_date
			logger.info('========================== Completed suggesting appointment date =================================== @ '  + Time.now.to_s)
		end
    
		@drug_given_before = PatientService.drug_given_before(@patient, session[:datetime])


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
		@art_first_visit = is_first_hiv_clinic_consultation(@patient.id)
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

        if  ['HIV_CLINIC_CONSULTATION', 'TB_VISIT', 'HIV_STAGING'].include?((params[:encounter_type].upcase rescue ''))
			@local_tb_dot_sites_tag = tb_dot_sites_tag 
			for encounter in @current_encounters.reverse do
				if encounter.name.humanize.include?('Hiv staging') || encounter.name.humanize.include?('Tb visit') || encounter.name.humanize.include?('Hiv clinic consultation') 
					encounter = Encounter.find(encounter.id, :include => [:observations])
					for obs in encounter.observations do
						if obs.concept_id == ConceptName.find_by_name("IS PATIENT PREGNANT?").concept_id
							@is_patient_pregnant_value = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}"
						end

						if obs.concept_id == ConceptName.find_by_name("IS PATIENT BREAST FEEDING?").concept_id
							@is_patient_breast_feeding_value = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}"
						end
					end

					if encounter.name.humanize.include?('Tb visit') || encounter.name.humanize.include?('Hiv clinic consultation')
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

		if (params[:encounter_type].upcase rescue '') == 'HIV_STAGING' or (params[:encounter_type].upcase rescue '') == 'HIV_CLINIC_REGISTRATION'
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

			if (params[:encounter_type].upcase rescue '') == 'HIV_STAGING'
				#added current weight to use on HIV staging for infants
				@current_weight = PatientService.get_patient_attribute_value(@patient,
													                  "current_weight")
				if !@retrospective
					@who_stage_i = @who_stage_i - concept_set('Unspecified Staging Conditions')
					@who_stage_ii = @who_stage_ii - concept_set('Unspecified Staging Conditions')
					@who_stage_iii = @who_stage_iii - concept_set('Unspecified Staging Conditions')
					@who_stage_iv = @who_stage_iv - concept_set('Unspecified Staging Conditions') - concept_set('Calculated WHO HIV staging conditions')
				end

				@moderate_wasting = []
				@severe_wasting = []
				if @patient_bean.age < 15
					median_weight_height = WeightHeightForAge.median_weight_height(@patient_bean.age_in_months, @patient.person.gender) rescue []
					current_weight_percentile = (@current_weight/(median_weight_height[0])*100)

					if current_weight_percentile >= 70 && current_weight_percentile <= 79
						@moderate_wasting = ["Moderate unexplained wasting/malnutrition not responding to treatment (weight-for-height/ -age 70-79% or muac 11-12 cm)"]
						@who_stage_iii = @who_stage_iii.flatten.uniq if CoreService.get_global_property_value('use.extended.staging.questions').to_s != "true"       
						@severe_wasting = []
					elsif current_weight_percentile < 70
						@severe_wasting = ["Severe unexplained wasting or malnutrition not responding to treatment (weight-for-height/ -age <70% or MUAC less than 11cm or oedema)"]
						@who_stage_iv = @who_stage_iv.flatten.uniq if CoreService.get_global_property_value('use.extended.staging.questions').to_s != "true"
						@moderate_wasting = []
					end
				end
				
				reason_for_art = @patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue []
		        @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
				if !@reason_for_art_eligibility.nil? && @reason_for_art_eligibility.upcase == 'NONE'
					@reason_for_art_eligibility = nil				
				end
			end
			
			if @tb_status == true && @hiv_status != 'Negative'
		    	tb_hiv_exclusions = [['Pulmonary tuberculosis (current)', 'Pulmonary tuberculosis (current)'], 
					['Tuberculosis (PTB or EPTB) within the last 2 years', 'Tuberculosis (PTB or EPTB) within the last 2 years']]
				@who_stage_iii = @who_stage_iii - tb_hiv_exclusions
			end

  			
			@confirmatory_hiv_test_type = @patient.person.observations.question("CONFIRMATORY HIV TEST TYPE").last.answer_concept_name.name rescue 'UNKNOWN'
		end

		@arv_drugs = nil
		if (params[:encounter_type].upcase rescue '') == 'HIV_CLINIC_REGISTRATION'
			other = []

=begin
			use_regimen_short_names = CoreService.get_global_property_value("use_regimen_short_names") rescue "false"
			show_other_regimen = ("show_other_regimen") rescue 'false'

			@answer_array = arv_regimen_answers(:patient => @patient,
				:use_short_names    => use_regimen_short_names == "true",
				:show_other_regimen => show_other_regimen      == "true")

			hiv_program = Program.find_by_name('HIV Program')
			current_weight = PatientService.get_patient_attribute_value(@patient, "current_weight")
			@answer_array = MedicationService.regimen_options(current_weight, hiv_program)
			@answer_array += [['Other', 'Other'], ['Unknown', 'Unknown']]
=end

			@arv_drugs = MedicationService.arv_drugs.collect { | drug | 
				if (CoreService.get_global_property_value('use_regimen_short_names').to_s == "true" rescue false)					
					other << [drug.concept.shortname, drug.concept.shortname] if (drug.concept.shortname.upcase.include?('OTHER') || drug.concept.shortname.upcase.include?('UNKNOWN'))
					[drug.concept.shortname, drug.concept.shortname] 
				else
					other << [drug.concept.fullname, drug.concept.fullname] if (drug.concept.fullname.upcase.include?('OTHER') || drug.concept.fullname.upcase.include?('UKNOWN'))
					[drug.concept.fullname, drug.concept.fullname]
				end
			}
			@arv_drugs = @arv_drugs - other
			@arv_drugs = @arv_drugs.sort {|a,b| a.to_s.downcase <=> b.to_s.downcase}
			@arv_drugs = @arv_drugs + other

			@require_hiv_clinic_registration = require_hiv_clinic_registration
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
        ["Treatment after default", "Treatment after default MDR-TB patient"],
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
      ],
      'source_of_referral' => [
        ['',''],
        ['Walk in', 'Walk in'],
        ['Index Patient', 'Index Patient'],
        ['HTC', 'HTC clinic'],
        ['ART', 'ART Clinic'],
        ['OPD', 'OPD'],
        ['PMTCT', 'PMTCT'],
        ['Private practitioner', 'Private practitioner'],
        ['Sputum collection point', 'Sputum collection point'],
        ['Other','Other']
      ]
    }
  end

 def is_holiday(suggest_date, holidays)
    holiday = false;
    holidays.each do |h|
      if (h.to_date.strftime('%A %d') == suggest_date.strftime('%A %d'))
        holiday = true;
      end
    end
    return holiday
 end

def return_original_suggested_date(suggested_date, booked_dates)
  suggest_original_date = nil
  #second_biggest_date_available = nil
  
  booked_dates.each do |booked_date|
    sdate = booked_date.to_s.split(":")[0].to_date
    
    if(sdate.to_date >= suggested_date.to_date)
      #second_biggest_date_available = suggested_date
      suggest_original_date = sdate
      suggested_date = sdate
    end
  end if booked_dates.to_s.size > 0
  
  @massage="All available days this calender week are fully booked"

  return suggest_original_date
end

  def is_below_limit(recommended_date, bookings)
    clinic_appointment_limit = CoreService.get_global_property_value('clinic.appointment.limit').to_i rescue 0
		clinic_appointment_limit = 0 if clinic_appointment_limit.blank?
		within_limit = true
		
    if (bookings.blank? || clinic_appointment_limit <= 0)
      within_limit = true;
    else
      recommended_date_limit = bookings[recommended_date] rescue 0

		  if (recommended_date_limit >= clinic_appointment_limit)
		    within_limit = false
		  end
    end

	return within_limit
 end

	def suggested_date(prescription_expiry_date, holidays, bookings, clinic_days)
		number_of_suggested_booked_dates_tried = 0

		skip = true
		recommended_date = prescription_expiry_date
		nearest_clinic_day = nil
    
		while skip
			clinic_days.each do |d|
			if (d.to_s.upcase == recommended_date.strftime('%A').to_s.upcase)
				nearest_clinic_day = recommended_date if nearest_clinic_day.blank?
				skip = is_holiday(recommended_date, holidays)
				break
			end
		end


		if (skip)
			recommended_date = recommended_date - 1.day
		else
			below_limit = is_below_limit(recommended_date, bookings)
			if (below_limit == false)
				recommended_date = recommended_date - 1.day
				skip = true
			end
		end

		number_of_suggested_booked_dates_tried += 1
		total_booked_dates = booked_dates.length rescue 0

		test = (number_of_suggested_booked_dates_tried > 4 && total_booked_dates > 0)
		if test
			recommended_date = nearest_clinic_day
		end
    end

    return recommended_date
   
 end

  def assign_close_to_expire_date(set_date,auto_expire_date)
    if (set_date < auto_expire_date)
      while (set_date < auto_expire_date)
        set_date = set_date + 1.day
      end
        #Give the patient a 2 day buffer*/
        set_date = set_date - 1.day
    end
    return set_date
  end

	def suggest_appointment_date
		#for now we disable this because we are already checking for this
		#in the browser - the method is suggested_return_date
		#@number_of_days_to_add_to_next_appointment_date = number_of_days_to_add_to_next_appointment_date(@patient, session[:datetime] || Date.today)

		dispensed_date = session[:datetime].to_date rescue Date.today
		prescription_expiry_date = prescription_expiry_date(@patient, dispensed_date)
		
		#if the patient is a child (age 14 or less) and the peads clinic days are set - we
		#use the peads clinic days to set the next appointment date		
		peads_clinic_days = CoreService.get_global_property_value('peads.clinic.days')
				
		if (@patient_bean.age <= 14 && !peads_clinic_days.blank?)
			clinic_days = peads_clinic_days
		else
			clinic_days = CoreService.get_global_property_value('clinic.days') || 'Monday,Tuesday,Wednesday,Thursday,Friday'		
		end
		clinic_days = clinic_days.split(',')		

		bookings = bookings_within_range(prescription_expiry_date)
		clinic_holidays = CoreService.get_global_property_value('clinic.holidays') || '1900-12-25,1900-03-03'
		clinic_holidays = clinic_holidays.split(',').map{|day|day.to_date}.join(',').split(',') rescue []
		
		limit = CoreService.get_global_property_value('clinic.appointment.limit') rescue 0

		return suggested_date(prescription_expiry_date ,clinic_holidays, bookings, clinic_days)
	end
	
	def prescription_expiry_date(patient, dispensed_date)
    	session_date = dispensed_date.to_date
    
		orders_made = PatientService.drugs_given_on(patient, session_date).reject{|o| !MedicationService.arv(o.drug_order.drug) }

		auto_expire_date = Date.today + 2.days
		
		if orders_made.blank?
			orders_made = PatientService.drugs_given_on(patient, session_date)
			auto_expire_date = orders_made.sort_by(&:auto_expire_date).first.auto_expire_date.to_date if !orders_made.blank?
		else
			auto_expire_date = orders_made.sort_by(&:auto_expire_date).first.auto_expire_date.to_date
		end

		orders_made.each do |order|
			amounts_dispensed = Observation.all(:conditions => ['concept_id = ? AND order_id = ?', 
						     ConceptName.find_by_name("AMOUNT DISPENSED").concept_id , order.id])
			total_dispensed = amounts_dispensed.sum{|amount| amount.value_numeric}
			
			amounts_brought_to_clinic = Observation.all( :joins => 'INNER JOIN drug_order USING (order_id)', 
				:conditions => ['obs.concept_id = ? AND drug_order.drug_inventory_id = ? AND obs.obs_datetime >= ? AND obs.obs_datetime <= ?', 
						     ConceptName.find_by_name("AMOUNT OF DRUG BROUGHT TO CLINIC").concept_id , order.drug_order.drug_inventory_id, session_date.to_date, session_date.to_date.to_s + ' 23:59:59'])

			total_brought_to_clinic = amounts_brought_to_clinic.sum{|amount| amount.value_numeric}

			total_brought_to_clinic = total_brought_to_clinic + amounts_brought_to_clinic.sum{|amount| (amount.value_text.to_f rescue 0)}

			prescription_duration = ((total_dispensed + total_brought_to_clinic)/order.drug_order.equivalent_daily_dose).to_i
			expire_date = order.start_date.to_date + prescription_duration.days

			auto_expire_date = expire_date  if expire_date  > auto_expire_date
		end
		
		return auto_expire_date - 2.days
	end
	
  def bookings_within_range(end_date = nil)
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    booked_dates = Hash.new(0)
   
    clinic_days = GlobalProperty.find_by_property("clinic.days")
    clinic_days = clinic_days.property_value.split(',') rescue 'Monday,Tuesday,Wednesday,Thursday,Friday'.split(',')

    count = 0
    start_date = end_date 
    while (count < 4)
      if clinic_days.include?(start_date.strftime("%A"))
        start_date -= 1.day
        count+=1
      else
        start_date -= 1.day
      end
    end

    Observation.find(:all,:order => "value_datetime DESC",
    :joins => "INNER JOIN encounter e USING(encounter_id)",
    :conditions => ["encounter_type = ? AND value_datetime IS NOT NULL
    AND (DATE(value_datetime) >= ? AND DATE(value_datetime) <= ?)",
    encounter_type.id,start_date,end_date]).map do | obs |
      next unless clinic_days.include?(obs.value_datetime.to_date.strftime("%A"))
      booked_dates[obs.value_datetime.to_date]+=1
    end  

    return booked_dates
  end
	
end
