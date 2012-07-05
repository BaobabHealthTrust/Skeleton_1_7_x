class Cohort
	
	attr :cohort, :art_defaulters
	attr_accessor :start_date, :end_date, :cohort, :patients_alive_and_on_art

	#attr_accessible :cohort

	@@first_registration_date = nil
	@@program_id = nil
  
	# Initialize class
	def initialize(start_date, end_date)
		@start_date = start_date #"#{start_date} 00:00:00"
		@end_date = "#{end_date} 23:59:59"

		@@first_registration_date = PatientProgram.find(
		  :first,
		  :conditions =>["program_id = ? AND voided = 0",1],
		  :order => 'date_enrolled ASC'
		).date_enrolled.to_date rescue nil

		@@program_id = Program.find_by_name('HIV PROGRAM').program_id
	end

	def report(logger)
		return {} if @@first_registration_date.blank?
		cohort_report = {}
	
    # calculate defaulters before starting different threads
    # We need total alive and on art to use for filter patients under secondary
    # outcomes (e.g. regimens, tb status, side effects)
    
    logger.info("defaulted " + Time.now.to_s)  
    @art_defaulters ||= self.art_defaulted_patients

    logger.info("alive_on_art " + Time.now.to_s)
    @patients_alive_and_on_art ||= self.total_alive_and_on_art(@art_defaulters)
		threads = []

		threads << Thread.new do
				begin
					cohort_report['Total Presumed severe HIV disease in infants'] = []
					cohort_report['Total Confirmed HIV infection in infants (PCR)'] = []
					cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] = []
					cohort_report['Total WHO stage 2, total lymphocytes'] = []
					cohort_report['Total Unknown reason'] = []
					cohort_report['Total WHO stage 3'] = []
					cohort_report['Total WHO stage 4'] = []
					cohort_report['Total Patient pregnant'] = []
					cohort_report['Total Patient breastfeeding'] = []
					cohort_report['Total HIV infected'] = []

					( self.start_reason(@@first_registration_date, @end_date) || [] ).each do | collection_reason |

						reason = ''
						if !collection_reason.name.blank?
							reason = collection_reason.name
						end

						if reason.match(/Presumed/i)
							cohort_report['Total Presumed severe HIV disease in infants'] << collection_reason.patient_id
						elsif reason.match(/Confirmed/i) or reason.match(/HIV DNA polymerase chain reaction/i)
							cohort_report['Total Confirmed HIV infection in infants (PCR)'] << collection_reason.patient_id
						elsif reason.match(/WHO STAGE I /i) or reason.match(/CD/i)
							cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
						elsif reason.match(/WHO STAGE II /i) or reason.match(/lymphocyte/i)
							cohort_report['Total WHO stage 2, total lymphocytes'] << collection_reason.patient_id
						elsif reason.match(/WHO STAGE III /i)
							cohort_report['Total WHO stage 3'] << collection_reason.patient_id
						elsif reason.match(/WHO STAGE IV /i)
							cohort_report['Total WHO stage 4'] << collection_reason.patient_id
						elsif reason.strip.humanize == 'Patient pregnant'
							cohort_report['Total Patient pregnant'] << collection_reason.patient_id
						elsif reason.match(/Breastfeeding/i)
							cohort_report['Total Patient breastfeeding'] << collection_reason.patient_id
						elsif reason.strip.upcase == 'HIV INFECTED'
							cohort_report['Total HIV infected'] << collection_reason.patient_id
						else 
							cohort_report['Total Unknown reason'] << collection_reason.patient_id
						end
					end
				rescue Exception => e
					Thread.current[:exception] = e
				end
		end

		threads << Thread.new do
				begin
					cohort_report['Total registered'] = self.total_registered(@@first_registration_date)
					cohort_report['Newly total registered'] = self.total_registered

					logger.info("initiated_on_art " + Time.now.to_s)
					cohort_report['Patients initiated on ART'] = self.patients_initiated_on_art_first_time
					cohort_report['Total Patients initiated on ART'] = self.patients_initiated_on_art_first_time(@@first_registration_date)
				rescue Exception => e
					Thread.current[:exception] = e
				end
		end

		threads << Thread.new do
				begin
					logger.info("male " + Time.now.to_s)
					cohort_report['Newly registered male'] = self.total_registered_by_gender_age(@start_date, @end_date,'M')
					cohort_report['Total registered male'] = self.total_registered_by_gender_age(@@first_registration_date, @end_date,'M')

					logger.info("non-pregnant " + Time.now.to_s)
					cohort_report['Newly registered women (non-pregnant)'] = self.non_pregnant_women(@start_date, @end_date)
					cohort_report['Total registered women (non-pregnant)'] = self.non_pregnant_women(@@first_registration_date, @end_date)
				rescue Exception => e
					Thread.current[:exception] = e
				end
		end

		threads << Thread.new do
				begin
					logger.info("pregnant " + Time.now.to_s)
					cohort_report['Newly registered women (pregnant)'] = self.pregnant_women(@start_date, @end_date)
					cohort_report['Total registered women (pregnant)'] = self.pregnant_women(@@first_registration_date, @end_date)

				rescue Exception => e
					Thread.current[:exception] = e
				end
		end

		threads << Thread.new do
				begin
					logger.info("adults " + Time.now.to_s)
					cohort_report['Newly registered adults'] = self.total_registered_by_gender_age(@start_date, @end_date, nil, 5479, 109500)
					cohort_report['Total registered adults'] = self.total_registered_by_gender_age(@@first_registration_date, @end_date, nil, 5479, 109500)
				rescue Exception => e
					Thread.current[:exception] = e
				end
		end

		threads << Thread.new do
				begin
					logger.info("children " + Time.now.to_s)
					# Child min age = 2 yrs = (365.25 * 2) = 730.5 == 731 days to nearest day
					cohort_report['Newly registered children'] = self.total_registered_by_gender_age(@start_date, @end_date, nil, 731, 5479)
					cohort_report['Total registered children'] = self.total_registered_by_gender_age(@@first_registration_date, @end_date, nil, 731, 5479)
				rescue Exception => e
					Thread.current[:exception] = e
				end
		end

		threads << Thread.new do
				begin
					logger.info("infants " + Time.now.to_s)
					cohort_report['Newly registered infants'] = self.total_registered_by_gender_age(@start_date, @end_date, nil, 0, 731)
					cohort_report['Total registered infants'] = self.total_registered_by_gender_age(@@first_registration_date, @end_date, nil, 0, 731)

				rescue Exception => e
					Thread.current[:exception] = e
				end
		end

		threads << Thread.new do
			begin
				logger.info("reinitiated_on_art " + Time.now.to_s)    
				cohort_report['Patients reinitiated on ART'] = self.patients_reinitiated_on_art
				cohort_report['Total Patients reinitiated on ART'] = self.patients_reinitiated_on_art(@@first_registration_date)

			rescue Exception => e
				Thread.current[:exception] = e
			end
		end    

		# Run the threads up to this point
		threads.each do |thread|				
			thread.join
			if thread[:exception]
				 # log it somehow, or even re-raise it if you
				 # really want, it's got it's original backtrace.
				 raise thread[:exception].message + ' ' + thread[:exception].backtrace.to_s
			end
		end

		threads = []


		threads << Thread.new do
			begin
				logger.info("start_reason " + Time.now.to_s)
				cohort_report['Presumed severe HIV disease in infants'] = []
				cohort_report['Confirmed HIV infection in infants (PCR)'] = []
				cohort_report['WHO stage 1 or 2, CD4 below threshold'] = []
				cohort_report['WHO stage 2, total lymphocytes'] = []
				cohort_report['Unknown reason'] = []
				cohort_report['WHO stage 3'] = []
				cohort_report['WHO stage 4'] = []
				cohort_report['Patient pregnant'] = []
				cohort_report['Patient breastfeeding'] = []
				cohort_report['HIV infected'] = []

 				( self.start_reason || [] ).each do | collection_reason |

					reason = ''
					if !collection_reason.name.blank?
						reason = collection_reason.name
					end

				  if reason.match(/Presumed/i)
				    cohort_report['Presumed severe HIV disease in infants'] << collection_reason.patient_id
				  elsif reason.match(/Confirmed/i) or reason.match(/HIV DNA polymerase chain reaction/i)
				    cohort_report['Confirmed HIV infection in infants (PCR)'] << collection_reason.patient_id
				  elsif reason.match(/WHO STAGE I /i) or reason.match(/CD/i)
				    cohort_report['WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
				  elsif reason.match(/WHO STAGE II /i) or reason.match(/lymphocyte/i)
				    cohort_report['WHO stage 2, total lymphocytes'] << collection_reason.patient_id
				  elsif reason.match(/WHO STAGE III /i)
				    cohort_report['WHO stage 3'] << collection_reason.patient_id
				  elsif reason.match(/WHO STAGE IV /i)
				    cohort_report['WHO stage 4'] << collection_reason.patient_id
				  elsif reason.strip.humanize == 'Patient pregnant'
				    cohort_report['Patient pregnant'] << collection_reason.patient_id
				  elsif reason.match(/Breastfeeding/i)
				    cohort_report['Patient breastfeeding'] << collection_reason.patient_id
				  elsif reason.strip.upcase == 'HIV INFECTED'
				    cohort_report['HIV infected'] << collection_reason.patient_id
				  else 
				    cohort_report['Unknown reason'] << collection_reason.patient_id
				  end
				end
	

			rescue Exception => e
				Thread.current[:exception] = e
			end
		end
		threads << Thread.new do
			begin
				cohort_report['Defaulted'] = @art_defaulters
				cohort_report['Total alive and on ART'] = @patients_alive_and_on_art
				cohort_report['Died total'] = self.total_number_of_dead_patients

		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads << Thread.new do
			begin
				cohort_report['Died within the 1st month after ART initiation'] = self.total_number_of_died_within_range(0, 30.4375)
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads << Thread.new do
			begin
				cohort_report['Died within the 2nd month after ART initiation'] = self.total_number_of_died_within_range(30.4375, 60.875)
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads << Thread.new do
			begin
				cohort_report['Died within the 3rd month after ART initiation'] = self.total_number_of_died_within_range(60.875, 91.3125)
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads << Thread.new do
			begin
				cohort_report['Died after the end of the 3rd month after ART initiation'] = self.total_number_of_died_within_range(91.3125, 1000000)
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads << Thread.new do
			begin
				
				logger.info("txfrd_out " + Time.now.to_s)
				cohort_report['Transferred out'] = self.transferred_out_patients
				
				logger.info("stopped_arvs " + Time.now.to_s)
				cohort_report['Stopped taking ARVs'] = self.art_stopped_patients
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads << Thread.new do
			begin
				logger.info("tb_status " + Time.now.to_s)
				tb_status_outcomes = self.tb_status
				cohort_report['TB suspected'] = tb_status_outcomes['TB STATUS']['Suspected']
				cohort_report['TB not suspected'] = tb_status_outcomes['TB STATUS']['Not Suspected']
				cohort_report['TB confirmed not treatment'] = tb_status_outcomes['TB STATUS']['Not on treatment']
				cohort_report['TB confirmed on treatment'] = tb_status_outcomes['TB STATUS']['On Treatment']
				cohort_report['TB Unknown'] = tb_status_outcomes['TB STATUS']['Unknown']
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end


		threads << Thread.new do
			begin
				logger.info("regimens " + Time.now.to_s)
				cohort_report['Regimens'] = self.regimens(@@first_registration_date)
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads.each do |thread|				
			thread.join
			if thread[:exception]
				 # log it somehow, or even re-raise it if you
				 # really want, it's got it's original backtrace.
				 raise thread[:exception].message + ' ' + thread[:exception].backtrace.to_s
			end
		end
		
		threads = []

		threads << Thread.new do
			begin
		    	cohort_report['Total patients with side effects'] = self.patients_with_side_effects

				logger.info("current_episode_of_tb " + Time.now.to_s)
				cohort_report['Current episode of TB'] = self.current_episode_of_tb
				cohort_report['Total Current episode of TB'] = self.current_episode_of_tb(@@first_registration_date, @end_date)
			rescue Exception => e
				Thread.current[:exception] = e
			end
		end

		threads << Thread.new do
			begin
				logger.info("adherence " + Time.now.to_s)
				cohort_report['Patients with 0 - 6 doses missed at their last visit'] = self.patients_with_0_to_6_doses_missed_at_their_last_visit
				cohort_report['Patients with 7+ doses missed at their last visit'] = self.patients_with_7_plus_doses_missed_at_their_last_visit
			rescue Exception => e
				Thread.current[:exception] = e
			end
		end

		threads << Thread.new do
			begin
				logger.info("tb_within_last_year " + Time.now.to_s)
				# these 2 are counted after threads. Don't append .length here
				cohort_report['TB within the last 2 years'] = self.tb_within_the_last_2_yrs
				cohort_report['Total TB within the last 2 years'] = self.tb_within_the_last_2_yrs(@@first_registration_date, @end_date)

				logger.info("ks " + Time.now.to_s)
				cohort_report['Kaposis Sarcoma'] = self.kaposis_sarcoma
				cohort_report['Total Kaposis Sarcoma'] = self.kaposis_sarcoma(@@first_registration_date,@end_date)
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads.each do |thread|				
			thread.join
			if thread[:exception]
				 # log it somehow, or even re-raise it if you
				 # really want, it's got it's original backtrace.
				 raise thread[:exception].message + ' ' + thread[:exception].backtrace.to_s
			end
		end
		cohort_report['Total transferred in patients'] = (cohort_report['Total registered'] - 
                                                      cohort_report['Total Patients reinitiated on ART'] -
                                                      cohort_report['Total Patients initiated on ART'])
                                                      
		cohort_report['Newly transferred in patients'] = (cohort_report['Newly total registered'] - 
                                                      cohort_report['Patients reinitiated on ART'] -
                                                      cohort_report['Patients initiated on ART'])
                                                     		
		cohort_report['Total Unknown age'] = cohort_report['Total registered'] - (cohort_report['Total registered adults'] +
				                            cohort_report['Total registered children'] +
				                            cohort_report['Total registered infants'])

		cohort_report['New Unknown age'] = cohort_report['Newly total registered']-(cohort_report['Newly registered adults'] +
				                            cohort_report['Newly registered children'] +
				                            cohort_report['Newly registered infants'])
	                                        
		current_episode = cohort_report['Current episode of TB']
		total_current_episode = cohort_report['Total Current episode of TB']
		
		
		cohort_report['TB within the last 2 years'] = cohort_report['TB within the last 2 years'] - current_episode
		cohort_report['Total TB within the last 2 years'] = cohort_report['Total TB within the last 2 years'] - current_episode		
		
		cohort_report['No TB'] = (cohort_report['Newly total registered'] - (current_episode + cohort_report['TB within the last 2 years']))	
		cohort_report['Total No TB'] = (cohort_report['Total registered'] - (total_current_episode + cohort_report['Total TB within the last 2 years']))	

		#cohort_report['Unknown reason'] += (cohort_report['Newly total registered'] - total_for_start_reason_quarterly)
		#cohort_report['Total Unknown reason'] += (cohort_report['Newly total registered'] - total_for_start_reason_cumulative)

		cohort_report['Unknown outcomes'] = cohort_report['Total registered'] -
				                            (cohort_report['Total alive and on ART'] +
				                              cohort_report['Defaulted'] +
				                              cohort_report['Died total'] +
				                              cohort_report['Stopped taking ARVs'] +
				                              cohort_report['Transferred out'])
		self.cohort = cohort_report
		self.cohort
	end

	def total_registered(start_date = @start_date, end_date = @end_date)
		patients = []
	  PatientProgram.find_by_sql("SELECT * FROM earliest_start_date 
	    WHERE earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'").each do | patient | 
			patients << patient.patient_id
		end
        return patients   
										

		#start_date = @start_date
		#end_date = @end_date
	end

	def patients_initiated_on_art_first_time(start_date = @start_date, end_date = @end_date)

    # Some patients have Ever registered at ART clinic = Yes but without any
    # original start date
    #
    # 7937 = Ever registered at ART clinic
    # 1065 = Yes
    patients = []
    PatientProgram.find_by_sql("SELECT esd.*
      FROM earliest_start_date esd
      LEFT JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id
      LEFT JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id
      WHERE esd.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}' AND
              (ero.obs_id IS NULL)
      GROUP BY esd.patient_id").each do | patient | 
			patients << patient.patient_id
		end
        return patients   

=begin
    PatientProgram.find_by_sql("SELECT esd.*,MIN(o.value_text) AS original_start_date
	    FROM earliest_start_date esd
	    LEFT JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id
			LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
			GROUP BY esd.patient_id
	    HAVING esd.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}' AND
	           original_start_date IS NULL")
=end

	end

	def transferred_in_patients(start_date = @start_date, end_date = @end_date)
=begin
      self.total_registered(start_date, end_date).map(&:patient_id) - (
      self.patients_reinitiated_on_art(start_date, end_date).map(&:patient_id) +
      self.patients_initiated_on_art_first_time(start_date, end_date).map(&:patient_id))
=end
	patients = []
    no_concept_id = ConceptName.find_by_name("NO").concept_id
    art_last_taken_concept_id = ConceptName.find_by_name("Date ART last taken").concept_id
    taken_art_last_two_months_id = ConceptName.find_by_name("Has the patient taken ART in the last two months").concept_id
    
    PatientProgram.find_by_sql("SELECT esd.*
     		FROM earliest_start_date esd
     		INNER JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id
     		INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id
    		LEFT JOIN (SELECT * FROM obs o 
    		           WHERE ((o.concept_id = #{art_last_taken_concept_id} AND
                      (DATEDIFF(o.obs_datetime,o.value_datetime)) > 60) OR
                      (o.concept_id = #{taken_art_last_two_months_id} AND 
                      (o.value_coded = #{no_concept_id})))) AS 
                      ro ON e.encounter_id = ro.encounter_id
            WHERE esd.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}' AND
                      ro.obs_id IS NULL
            GROUP BY esd.patient_id").each do | patient | 
			patients << patient.patient_id
		end
        return patients   
	end

	def total_registered_by_gender_age(start_date = @start_date, end_date = @end_date, sex = nil, min_age = nil, max_age = nil)
		conditions = ''
		patients = []
		if min_age and max_age
		  conditions = "AND DATEDIFF(initiation_date, person.birthdate) >= #{min_age}
				        AND DATEDIFF(initiation_date, person.birthdate) < #{max_age}"
		end

		if sex
		  conditions += "AND person.gender = '#{sex}'"
		end

    PatientProgram.find_by_sql(
      "SELECT esd.*,person.gender,person.birthdate,
        IF(ISNULL(MIN(sdo.value_datetime)), earliest_start_date,
        MIN(sdo.value_datetime)) AS initiation_date
	    FROM earliest_start_date esd
	      LEFT JOIN person ON person.person_id = esd.patient_id
	      LEFT JOIN start_date_observation sdo ON esd.patient_id = sdo.person_id
			GROUP BY esd.patient_id
	    HAVING esd.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}' #{conditions}").each do | patient | 
			patients << patient.patient_id
		end
        return patients   

	end

	def non_pregnant_women(start_date = @start_date, end_date = @end_date)
		all_women =  self.total_registered_by_gender_age(start_date, end_date, 'F')
		non_pregnant_women = (all_women - self.pregnant_women(start_date, end_date))
	end

	def pregnant_women(start_date = @start_date, end_date = @end_date)
		patients = []
		PatientProgram.find_by_sql("SELECT patient_id, earliest_start_date, o.obs_datetime 
				FROM earliest_start_date p
					INNER JOIN patient_pregnant_obs o ON p.patient_id = o.person_id
				WHERE earliest_start_date >= '#{start_date}'
					AND earliest_start_date <= '#{end_date}'
					AND DATEDIFF(o.obs_datetime, earliest_start_date) <= 30
					AND DATEDIFF(o.obs_datetime, earliest_start_date) > -1
        GROUP BY patient_id").each do | patient | 
			patients << patient.patient_id
		end
        return patients   

	end

	def start_reason(start_date = @start_date, end_date = @end_date)
		#start_reason_hash = Hash.new(0)
	    reason_concept_id = ConceptName.find_by_name("REASON FOR ART ELIGIBILITY").concept_id

		PatientProgram.find_by_sql("SELECT e.patient_id, name FROM earliest_start_date e
											LEFT JOIN obs o ON e.patient_id = o.person_id AND o.concept_id = #{reason_concept_id} AND o.voided = 0
											LEFT JOIN concept_name n ON n.concept_id = o.value_coded AND n.concept_name_type = 'FULLY_SPECIFIED' AND n.voided = 0
										WHERE earliest_start_date >= '#{start_date}'
											AND earliest_start_date <= '#{end_date}'
										GROUP BY e.patient_id")

	end

	def tb_within_the_last_2_yrs(start_date = @start_date, end_date = @end_date)
		tb_concept_id = ConceptName.find_by_name("PULMONARY TUBERCULOSIS WITHIN THE LAST 2 YEARS").concept_id
		self.patients_with_start_cause(start_date, end_date, [tb_concept_id, 2624])
	end

	def patients_with_start_cause(start_date = @start_date, end_date = @end_date, concept_ids = nil)
		patients = []

		if !concept_ids.blank?

			concept_ids = [concept_ids] if concept_ids.class != Array
      
      concept_ids.each do | concept |
        Observation.find_by_sql("SELECT DISTINCT patient_id, earliest_start_date, current_value_for_obs_at_initiation(patient_id, earliest_start_date, 52, '#{concept}', '#{end_date}') AS obs_value FROM earliest_start_date e  
              WHERE earliest_start_date >= '#{start_date}'
              AND earliest_start_date <= '#{end_date}'
              HAVING obs_value = 1065").each do | patient | 
          patients << patient.patient_id
        end
      end
		end
    patients = patients.uniq
    return patients   

	end

	def kaposis_sarcoma(start_date = @start_date, end_date = @end_date)
		concept_id = ConceptName.find_by_name("KAPOSIS SARCOMA").concept_id
		self.patients_with_start_cause(start_date,end_date, concept_id)
	end

	def total_alive_and_on_art(defaulted_patients = self.art_defaulted_patients)
=begin
		on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
		state = ProgramWorkflowState.find(
		  :first,
		  :conditions => ["concept_id IN (?)",
					      on_art_concept_name.map{|c|c.concept_id}]
		).program_workflow_state_id

		PatientState.find_by_sql("SELECT * FROM (
			SELECT s.patient_program_id, patient_id,patient_state_id,start_date,
				   n.name name,state
			FROM patient_state s
			LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id
			LEFT JOIN program_workflow pw ON pw.program_id = p.program_id
			LEFT JOIN program_workflow_state w ON w.program_workflow_id = pw.program_workflow_id
			AND w.program_workflow_state_id = s.state
			LEFT JOIN concept_name n ON w.concept_id = n.concept_id
			WHERE p.voided = 0 AND s.voided = 0
			AND (s.start_date >= '#{@@first_registration_date}'
			AND s.start_date <= '#{@end_date}')
			AND p.program_id = #{@@program_id}
			ORDER BY patient_state_id DESC, start_date DESC
		  ) K
		  GROUP BY K.patient_id HAVING (state = #{state})
		  ORDER BY K.patient_state_id DESC, K.start_date DESC")
=end
    
    	patients = []
		  if @total_alive_and_on_art.blank?
		 		PatientProgram.find_by_sql("SELECT e.patient_id, current_state_for_program(e.patient_id, 1, '#{@end_date}') AS state 
		 									FROM earliest_start_date e
											WHERE earliest_start_date <=  '#{@end_date}'
											HAVING state = 7").reject{|t| defaulted_patients.include?(t.patient_id) }.each do | patient | 
					patients << patient.patient_id
				end
				@total_alive_and_on_art = patients
			else
				patients = @total_alive_and_on_art
			end

			return patients  
	end

=begin
	def died_total
		self.outcomes_total('PATIENT DIED', @@first_registration_date, @end_date)
	end
=end

	def total_number_of_dead_patients
		self.outcomes_total('PATIENT DIED', @@first_registration_date, @end_date)
    
    #PatientProgram.find_by_sql("SELECT patient_id, current_state_for_program(patient_id, 1, '#{@end_date}') AS state FROM earliest_start_date
		#								WHERE earliest_start_date <=  '#{@end_date}'
		#								HAVING state = 3")
	end

	def total_number_of_died_within_range(min_days = 0, max_days = 0)								
    concept_name = ConceptName.find_all_by_name("PATIENT DIED")
    state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
                      concept_name.map{|c|c.concept_id}]
    ).program_workflow_state_id

	patients = []    										

   	PatientProgram.find_by_sql(
   		"SELECT e.patient_id, current_state_for_program(e.patient_id, 1, '#{@end_date}') AS state, death_date,
				IF(ISNULL(MIN(sdo.value_datetime)), earliest_start_date, MIN(sdo.value_datetime)) AS initiation_date
			FROM earliest_start_date e
				LEFT JOIN start_date_observation sdo ON e.patient_id = sdo.person_id
			WHERE earliest_start_date <=  '#{@end_date}'
			GROUP BY e.patient_id
			HAVING state = #{state} AND 
				DATEDIFF(death_date, initiation_date) BETWEEN #{min_days} AND #{max_days}").each do | patient | 
			patients << patient.patient_id
		end
        return patients   
	end

	def transferred_out_patients
		self.outcomes_total('PATIENT TRANSFERRED OUT', @@first_registration_date)
	end

	def art_defaulted_patients
		patients = []
		if @art_defaulters.blank?
			@art_defaulters ||= PatientProgram.find_by_sql("SELECT e.patient_id, current_defaulter(e.patient_id, '#{@end_date}') AS def
											FROM earliest_start_date e LEFT JOIN person p ON p.person_id = e.patient_id
											WHERE e.earliest_start_date <=  '#{@end_date}' AND p.dead=0
											HAVING def = 1 AND current_state_for_program(patient_id, 1, '#{@end_date}') NOT IN (6, 2, 3)").each do | patient | 
				patients << patient.patient_id
			end
			@art_defaulters = patients
		else
     patients = @art_defaulters
    end
    
		return patients 
	end


	def art_stopped_patients
				self.outcomes_total('Treatment stopped', @@first_registration_date)

	end

	def tb_status
		tb_status_hash = {} ; status = []
		tb_status_hash['TB STATUS'] = {'Unknown' => 0,'Suspected' => 0,'Not Suspected' => 0,'On Treatment' => 0,'Not on treatment' => 0} 
		tb_status_concept_id = ConceptName.find_by_name('TB STATUS').concept_id
		hiv_clinic_consultation_encounter_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id
=begin
    status = PatientState.find_by_sql("SELECT * FROM (
                          SELECT e.patient_id,n.name tbstatus,obs_datetime,e.encounter_datetime,s.state
                          FROM patient_state s
                          LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id   
                          
                          LEFT JOIN encounter e ON e.patient_id = p.patient_id
                          
                          LEFT JOIN obs ON obs.encounter_id = e.encounter_id
                          LEFT JOIN concept_name n ON obs.value_coded = n.concept_id
                          WHERE p.voided = 0
                          AND s.voided = 0
                          AND obs.obs_datetime = e.encounter_datetime
                          AND (s.start_date >= '#{start_date}'
                          AND s.start_date <= '#{end_date}')
                          AND obs.concept_id = #{tb_status_concept_id}
                          AND e.encounter_type = #{hiv_clinic_consultation_encounter_id}
                          AND p.program_id = #{@@program_id}
                          ORDER BY e.encounter_datetime DESC, patient_state_id DESC , start_date DESC) K
                          GROUP BY K.patient_id
                          ORDER BY K.encounter_datetime DESC , K.obs_datetime DESC")
=end      
		states = Hash.new()

    @art_defaulters ||= self.art_defaulted_patients
		@patients_alive_and_on_art ||= self.total_alive_and_on_art(@art_defaulters)
		@patient_id_on_art_and_alive = @patients_alive_and_on_art
		@patient_id_on_art_and_alive = [0] if @patient_id_on_art_and_alive.blank?

		status = PatientState.find_by_sql(
													"SELECT e.patient_id, current_value_for_obs(e.patient_id, #{hiv_clinic_consultation_encounter_id}, #{tb_status_concept_id}, '#{end_date}') AS obs_value 
													FROM earliest_start_date e
													WHERE earliest_start_date <= '#{end_date}'
													AND e.patient_id IN (#{@patient_id_on_art_and_alive.join(',')}) ").each do |state|
														states[state.patient_id] = state.obs_value
												  end

		tb_not_suspected_id = ConceptName.find_by_name('TB NOT SUSPECTED').concept_id
		tb_suspected_id = ConceptName.find_by_name('TB SUSPECTED').concept_id
		tb_confirmed_on_treatment_id = ConceptName.find_by_name('CONFIRMED TB ON TREATMENT').concept_id
		tb_confirmed_not_on_treatment_id = ConceptName.find_by_name('CONFIRMED TB NOT ON TREATMENT').concept_id

		tb_status_hash['TB STATUS']['Not Suspected'] = []
		tb_status_hash['TB STATUS']['Suspected'] = []
		tb_status_hash['TB STATUS']['On Treatment'] = []
		tb_status_hash['TB STATUS']['Not on treatment'] = []
		tb_status_hash['TB STATUS']['Unknown'] = []

		( states || [] ).each do | patient_id, state |
			if state.to_i == tb_not_suspected_id
				tb_status_hash['TB STATUS']['Not Suspected'] << patient_id.to_i
			elsif state.to_i == tb_suspected_id
				tb_status_hash['TB STATUS']['Suspected'] << patient_id.to_i
			elsif state.to_i == tb_confirmed_on_treatment_id.to_i
				tb_status_hash['TB STATUS']['On Treatment'] << patient_id.to_i
			elsif state.to_i == tb_confirmed_not_on_treatment_id
				tb_status_hash['TB STATUS']['Not on treatment'] << patient_id.to_i
			else
				tb_status_hash['TB STATUS']['Unknown'] << patient_id.to_i
			end
		end
		tb_status_hash
	end

  def outcomes_total(outcome, start_date=@start_date, end_date=@end_date)
    concept_name = ConceptName.find_all_by_name(outcome)
    state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
                      concept_name.map{|c|c.concept_id}]
    ).program_workflow_state_id
	patients = []
 	PatientProgram.find_by_sql("SELECT e.patient_id, current_state_for_program(e.patient_id, 1, '#{end_date}') AS state 
 									FROM earliest_start_date e
									WHERE earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
									HAVING state = #{state}").each do | patient | 
			patients << patient.patient_id
		end
        return patients   
  end

=begin
	def death_dates(start_date = @start_date, end_date = @end_date)
		start_date_death_date = [] 

		first_month = [] ; second_month = [] ; third_month = [] ; after_third_month = []

		first_month_date = [start_date.to_date,(start_date.to_date + 1.month)]
		second_month_date = [first_month_date[1],first_month_date[1] + 1.month]
		third_month_date = [second_month_date[1],second_month_date[1] + 1.month]

		( self.died_total || [] ).each do | state |
		  if (state.date_enrolled.to_date >= first_month_date[0]  and state.date_enrolled.to_date <= first_month_date[1] )
			  first_month << state
		  elsif (state.date_enrolled.to_date >= second_month_date[0]  and state.date_enrolled.to_date <= second_month_date[1] )
			  second_month << state
		  elsif (state.date_enrolled.to_date >= third_month_date[0]  and state.date_enrolled.to_date <= third_month_date[1] )
			  third_month << state
		  elsif (state.date_enrolled.to_date > third_month_date[1] )
			  after_third_month << state
		  end
		end
		[first_month, second_month, third_month, after_third_month]
	end
=end

	# Get patients reinitiated on art count
	def patients_reinitiated_on_art_ever
		patients = []
		Observation.find(:all, :joins => [:encounter], :conditions => ["concept_id = ? AND value_coded IN (?) AND encounter.voided = 0 \
			AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') <= ?", ConceptName.find_by_name("EVER RECEIVED ART").concept_id,
			ConceptName.find(:all, :conditions => ["name = 'YES'"]).collect{|c| c.concept_id},
			@end_date.to_date.strftime("%Y-%m-%d")]).each do | patient | 
			patients << patient.patient_id
		end
        return patients   
	end

=begin
	def patients_reinitiated_on_arts
		Observation.find(:all, :joins => [:encounter], :conditions => ["concept_id = ? AND value_coded IN (?) AND encounter.voided = 0 \
			AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') >= ? AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') <= ?",
			ConceptName.find_by_name("EVER RECEIVED ART").concept_id,
			ConceptName.find(:all, :conditions => ["name = 'YES'"]).collect{|c| c.concept_id},
			@start_date.to_date.strftime("%Y-%m-%d"), @end_date.to_date.strftime("%Y-%m-%d")]).length rescue 0
	end

  def patients_reinitiated_on_arts_ids
    Observation.find(:all, :joins => [:encounter], :conditions => ["concept_id = ? AND value_coded IN (?) AND encounter.voided = 0 \
        AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') >= ? AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') <= ?",
        ConceptName.find_by_name("EVER RECEIVED ART").concept_id,
        ConceptName.find(:all, :conditions => ["name = 'YES'"]).collect{|c| c.concept_id},
        @start_date.to_date.strftime("%Y-%m-%d"), @end_date.to_date.strftime("%Y-%m-%d")]).map{|patient| patient.person_id}
  end
=end

  def outcomes(start_date=@start_date, end_date=@end_date, outcome_end_date=@end_date, program_id = @@program_id, min_age=nil, max_age=nil,states = [])

    if min_age or max_age
      conditions = "AND TRUNCATE(DATEDIFF(p.date_enrolled, person.birthdate)/365,0) >= #{min_age}
                    AND TRUNCATE(DATEDIFF(p.date_enrolled, person.birthdate)/365,0) <= #{max_age}"
    end

    PatientState.find_by_sql("SELECT * FROM (
        SELECT s.patient_program_id, patient_id,patient_state_id,start_date,
               n.name name,state
        FROM patient_state s
        INNER JOIN patient_program p ON p.patient_program_id = s.patient_program_id
        INNER JOIN program_workflow pw ON pw.program_id = p.program_id
        INNER JOIN program_workflow_state w ON w.program_workflow_id = pw.program_workflow_id
                   AND w.program_workflow_state_id = s.state
        INNER JOIN concept_name n ON w.concept_id = n.concept_id
        INNER JOIN person ON person.person_id = p.patient_id
        WHERE p.voided = 0 AND s.voided = 0 #{conditions}
        AND (patient_start_date(patient_id) >= '#{start_date}'
        AND patient_start_date(patient_id) <= '#{end_date}')
        AND p.program_id = #{program_id}
        AND s.start_date <= '#{outcome_end_date}'
        ORDER BY patient_id DESC, patient_state_id DESC, start_date DESC
      ) K
      GROUP BY patient_id
      ORDER BY K.patient_state_id DESC , K.start_date DESC").map do |state|
        states << [state.patient_id , state.name]
      end
  end

  
  def first_registration_date
    @@first_registration_date
  end


  def arv_regimens(regimen_category)
    regimens = []
    if regimen_category == "non-standard"
      regimen_category = "UNKNOWN ANTIRETROVIRAL DRUG"
    end

    self.regimens.each do |reg_name, patient_ids|

      if reg_name == regimen_category
        patient_ids.each do |patient_id|
         regimens << patient_id
        end
      end
    end
    regimens
  end

  def regimens(start_date = @start_date, end_date = @end_date)
    regimen_hash = {}
    @art_defaulters ||= self.art_defaulted_patients
    @patients_alive_and_on_art ||= self.total_alive_and_on_art(@art_defaulters)
    patient_ids = @patients_alive_and_on_art
    patient_ids = [0] if patient_ids.blank?

    dispensing_encounter_id = EncounterType.find_by_name("DISPENSING").id
    regimen_category = ConceptName.find_by_name("REGIMEN CATEGORY").concept_id

    PatientProgram.find_by_sql(
      "SELECT e.patient_id,
              current_text_for_obs(e.patient_id, #{dispensing_encounter_id}, #{regimen_category}, '#{end_date}') AS regimen_category 
      FROM earliest_start_date e
      WHERE patient_id IN(#{patient_ids.join(',')}) AND
            earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
      ").each do | value |
  
        if value.regimen_category.blank?
          regimen_hash['UNKNOWN ANTIRETROVIRAL DRUG'] ||= []
          regimen_hash['UNKNOWN ANTIRETROVIRAL DRUG'] << value.patient_id
        else
          regimen_hash[value.regimen_category] ||= []
          regimen_hash[value.regimen_category] << value.patient_id
        end
      end

    regimen_hash
  end

=begin  
  def regimens_with_patient_ids(start_date = @start_date, end_date = @end_date)
    regimens = []
    regimen_hash = {}

    regimem_given_concept = ConceptName.find_by_name('ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT')
    PatientProgram.find_by_sql("SELECT patient_id , value_coded regimen_id, value_text regimen ,
                                age(LEFT(person.birthdate,10),LEFT(obs.obs_datetime,10),
                                LEFT(person.date_created,10),person.birthdate_estimated) person_age_at_drug_dispension  
                                FROM obs 
                                INNER JOIN patient_program p ON p.patient_id = obs.person_id
                                INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                INNER JOIN person ON person.person_id = p.patient_id
                                WHERE p.program_id = #{@@program_id}
                                AND obs.concept_id = #{regimem_given_concept.concept_id}
                                AND patient_start_date(patient_id) >= '#{start_date}'
                                AND patient_start_date(patient_id) <= '#{end_date}' 
                                GROUP BY patient_id 
                                ORDER BY obs.obs_datetime DESC").each do | value |
                                  if value.regimen.blank?
																		value.regimen = ConceptName.find_by_concept_id(value.regimen_id).concept.shortname								
		                                regimens << [value.regimen_id, 
		                                             value.regimen,
		                                             value.person_age_at_drug_dispension
		                                            ]
		                              else
		                              	regimens << [value.regimen_id, 
		                                             value.regimen,
		                                             value.person_age_at_drug_dispension
		                                            ]
		                              end
                                end
  end
=end


  def patients_reinitiated_on_art(start_date = @start_date, end_date = @end_date)
    
=begin
      self.total_registered(start_date, end_date).map(&:patient_id) - (
      self.transferred_in_patients(start_date, end_date).map(&:patient_id) +
      self.patients_initiated_on_art_first_time(start_date, end_date).map(&:patient_id))
=end
	patients = []
    yes_concept = ConceptName.find_by_name('YES').concept_id
		no_concept = ConceptName.find_by_name('NO').concept_id
    date_art_last_taken_concept = ConceptName.find_by_name('DATE ART LAST TAKEN').concept_id

    taken_arvs_concept = ConceptName.find_by_name('HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS').concept_id 
    
    PatientProgram.find_by_sql("SELECT esd.*
      FROM earliest_start_date esd
      LEFT JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id
      INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id
      LEFT JOIN obs o ON o.encounter_id = e.encounter_id AND
                         o.concept_id IN (#{date_art_last_taken_concept},#{taken_arvs_concept})
      WHERE  ((o.concept_id = #{date_art_last_taken_concept} AND
               (DATEDIFF(o.obs_datetime,o.value_datetime)) > 60) OR
             (o.concept_id = #{taken_arvs_concept} AND
              (o.value_coded = #{no_concept})
              ))
            AND
            esd.earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
      GROUP BY esd.patient_id").each do | patient | 
			patients << patient.patient_id
		end
        return patients   
  end
	
	def patients_with_doses_missed_at_their_last_visit(start_date = @start_date, end_date = @end_date)
		@art_defaulters ||= self.art_defaulted_patients
		@patients_alive_and_on_art ||= self.total_alive_and_on_art(@art_defaulters)
		patient_ids = @patients_alive_and_on_art
    patient_ids = [0] if patient_ids.blank?
    
		doses_missed_concept = ConceptName.find_by_name("MISSED HIV DRUG CONSTRUCT").concept_id
		
		patients = Observation.find_by_sql("SELECT DISTINCT person_id AS person_id, 
          earliest_start_date, obs.value_numeric, obs.value_text 
          FROM obs INNER JOIN earliest_start_date e ON obs.person_id = e.patient_id
					AND concept_id = #{doses_missed_concept} 
					AND voided = 0
					
					AND earliest_start_date >= '#{start_date}'
					AND earliest_start_date <= '#{end_date}'
					AND person_id IN (#{patient_ids.join(',')})")
		return patients
	end
	
	def patients_not_adherent_at_their_last_visit(start_date = @start_date, end_date = @end_date)
		@art_defaulters ||= self.art_defaulted_patients
		@patients_alive_and_on_art ||= self.total_alive_and_on_art(@art_defaulters)
		patient_ids = @patients_alive_and_on_art
    patient_ids = [0] if patient_ids.blank?
   
		art_adherence_concept = ConceptName.find_by_name("WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER").concept_id
		art_adherence_encounter = EncounterType.find_by_name("ART ADHERENCE").id

		patients = Observation.find_by_sql("SELECT DISTINCT person_id AS person_id, 
          earliest_start_date, obs.value_numeric, obs.value_text 
          FROM obs INNER JOIN earliest_start_date e ON obs.person_id = e.patient_id
					AND concept_id = #{art_adherence_concept} 
					AND voided = 0 
          AND current_text_for_obs(obs.person_id,#{art_adherence_encounter},
          #{art_adherence_concept},'#{end_date}') NOT BETWEEN 95 AND 105  
					
					AND earliest_start_date >= '#{start_date}'
					AND earliest_start_date <= '#{end_date}'
					AND person_id IN (#{patient_ids.join(',')})")
		return patients
	end
	
	def patients_adherent_at_their_last_visit(start_date = @start_date, end_date = @end_date)
		@art_defaulters ||= self.art_defaulted_patients
		@patients_alive_and_on_art ||= self.total_alive_and_on_art(@art_defaulters)
		patient_ids = @patients_alive_and_on_art
    patient_ids = [0] if patient_ids.blank?
   
		art_adherence_concept = ConceptName.find_by_name("WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER").concept_id
		art_adherence_encounter = EncounterType.find_by_name("ART ADHERENCE").id

		patients = Observation.find_by_sql("SELECT DISTINCT person_id AS person_id, 
          earliest_start_date, obs.value_numeric, obs.value_text 
          FROM obs INNER JOIN earliest_start_date e ON obs.person_id = e.patient_id
					AND concept_id = #{art_adherence_concept} 
					AND voided = 0 
          AND current_text_for_obs(obs.person_id,#{art_adherence_encounter},
          #{art_adherence_concept},'#{end_date}') BETWEEN 95 AND 105  
					
					AND earliest_start_date >= '#{start_date}'
					AND earliest_start_date <= '#{end_date}'
					AND person_id IN (#{patient_ids.join(',')})")
		return patients
	end
	
	def patients_with_0_to_6_doses_missed_at_their_last_visit(start_date = @start_date, end_date = @end_date)
    return patients_adherent_at_their_last_visit
		doses_missed_0_to_6 = []
		self.patients_with_doses_missed_at_their_last_visit.map do |doses_missed|
			missed_dose = doses_missed.value_text if !doses_missed.value_numeric
			if missed_dose.to_i < 7
				doses_missed_0_to_6 << doses_missed.person_id
			end
		end
		return doses_missed_0_to_6
	end
	
	def patients_with_7_plus_doses_missed_at_their_last_visit(start_date = @start_date, end_date = @end_date)
    return patients_not_adherent_at_their_last_visit
		doses_missed_7_plus = []
		self.patients_with_doses_missed_at_their_last_visit.map do |doses_missed|
			missed_dose = doses_missed.value_text if !doses_missed.value_numeric
			if missed_dose.to_i >= 7
				doses_missed_7_plus << doses_missed.person_id
			end
		end
		return doses_missed_7_plus
	end

  # EXTRAPULMONARY TUBERCULOSIS (EPTB) and Pulmonary TB (Concept Id 42)
  # 8206 
  def current_episode_of_tb(start_date = @start_date, end_date = @end_date)
    tb_concept_id = ConceptName.find_by_name("EXTRAPULMONARY TUBERCULOSIS (EPTB)").concept_id
    self.patients_with_start_cause(start_date, end_date, [tb_concept_id, 42, 8206])
  end

  def tb_status_with_patient_ids
    tb_status_hash = {} ; status = []
    tb_status_hash['TB STATUS'] = {'Unknown' => 0,'Suspected' => 0,'Not Suspected' => 0,'On Treatment' => 0,'Not on treatment' => 0} 
    tb_status_concept_id = ConceptName.find_by_name('TB STATUS').concept_id
    hiv_clinic_consultation_encounter_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id
=begin
    status = PatientState.find_by_sql("SELECT * FROM (
                          SELECT e.patient_id,n.name tbstatus,obs_datetime,e.encounter_datetime,s.state
                          FROM patient_state s
                          LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id   
                          LEFT JOIN encounter e ON e.patient_id = p.patient_id
                          LEFT JOIN obs ON obs.encounter_id = e.encounter_id
                          LEFT JOIN concept_name n ON obs.value_coded = n.concept_id
                          WHERE p.voided = 0
                          AND s.voided = 0
                          AND obs.obs_datetime = e.encounter_datetime
                          AND (s.start_date >= '#{start_date}'
                          AND s.start_date <= '#{end_date}')
                          AND obs.concept_id = #{tb_status_concept_id}
                          AND e.encounter_type = #{hiv_clinic_consultation_encounter_id}
                          AND p.program_id = #
{@@program_id}
                          ORDER BY e.encounter_datetime DESC, patient_state_id DESC , start_date DESC) K
                          GROUP BY K.patient_id
                          ORDER BY K.encounter_datetime DESC , K.obs_datetime DESC")
=end
		status = PatientProgram.find_by_sql("SELECT e.patient_id, current_value_for_obs(e.patient_id, #{hiv_clinic_consultation_encounter_id}, #{tb_status_concept_id}, '#{end_date}') AS obs_value 
												FROM earliest_start_date e
												WHERE earliest_start_date <= '#{end_date}'")
  end

  def side_effect_patients(start_date = @start_date, end_date = @end_date)
    side_effect_concept_ids =[ConceptName.find_by_name('PERIPHERAL NEUROPATHY').concept_id,
                              ConceptName.find_by_name('LEG PAIN / NUMBNESS').concept_id,
                              ConceptName.find_by_name('HEPATITIS').concept_id,
                              ConceptName.find_by_name('SKIN RASH').concept_id,
                              ConceptName.find_by_name('JAUNDICE').concept_id]

    encounter_type = EncounterType.find_by_name('HIV CLINIC CONSULTATION')
    concept_ids = [ConceptName.find_by_name('SYMPTOM PRESENT').concept_id,
                   ConceptName.find_by_name('DRUG INDUCED').concept_id]

    encounter_ids = Encounter.find(:all,:conditions => ["encounter_type = ? 
                    AND (patient_start_date(patient_id) >= '#{start_date}'
                    AND patient_start_date(patient_id) <= '#{end_date}')
                    AND (encounter_datetime >= '#{start_date}'
                    AND encounter_datetime <= '#{end_date}')",
                    encounter_type.id],:group => 'patient_id',:order => 'encounter_datetime DESC').map{| e | e.encounter_id }

    Observation.find(:all,
                     :conditions => ["encounter_id IN (#{encounter_ids.join(',')})
                     AND concept_id IN (?)
                     AND value_coded IN (#{side_effect_concept_ids.join(',')})",
                     concept_ids],
                     :group =>'person_id')
  end

  def patients_with_side_effects(start_date = @start_date, end_date = @end_date)
		side_effect_concept_ids =[ConceptName.find_by_name('PERIPHERAL NEUROPATHY').concept_id,
                              ConceptName.find_by_name('LEG PAIN / NUMBNESS').concept_id,
                              ConceptName.find_by_name('HEPATITIS').concept_id,
                              ConceptName.find_by_name('SKIN RASH').concept_id,
                              ConceptName.find_by_name('JAUNDICE').concept_id]

    hiv_clinic_consultation_encounter_id = EncounterType.find_by_name("HIV CLINIC CONSULTATION").id

    drug_induced_side_effect_id = ConceptName.find_by_name('DRUG INDUCED').concept_id
    @patients_alive_and_on_art ||= self.total_alive_and_on_art
    patient_ids = @patients_alive_and_on_art

    patient_ids = [0] if patient_ids.blank?
    
    side_effects_patients = Encounter.find_by_sql("SELECT e.patient_id FROM encounter e
                                                    INNER JOIN obs o ON o.encounter_id = e.encounter_id
                                                    WHERE e.encounter_type = #{hiv_clinic_consultation_encounter_id}
                                                    AND e.patient_id IN (#{patient_ids.join(',')})
                                                    AND o.value_coded IN (#{side_effect_concept_ids.join(',')})
                                                    AND o.concept_id = #{drug_induced_side_effect_id}
                                                    AND o.voided = 0
                                                    AND e.encounter_datetime = (SELECT MAX(e1.encounter_datetime) FROM encounter e1
                                                                                  WHERE e1.patient_id = e.patient_id
                                                                                  AND e1.encounter_type = e.encounter_type  
                                                                                  AND e1.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}'
                                                                                  AND e1.voided = 0)
                                                    GROUP BY e.patient_id"
                                                    )
                                                 
   side_effects_patients

	end

  private

  def cohort_regimen_name(name , age)
    case name
      when 'd4T/3TC/NVP'
        return '1A' if age > 14
        return '1P'
      when 'd4T/3TC + d4T/3TC/NVP (Starter pack)'
        return '1A' if age > 14
        return '1P'
      when 'AZT/3TC/NVP'
        return '2A' if age > 14
        return '2P'
      when 'AZT/3TC + AZT/3TC/NVP (Starter pack)'
        return '2A' if age > 14
        return '2P'
      when 'd4T/3TC/EFV'
        return '3A' if age > 14
        return '3P'
      when 'AZT/3TC+EFV'
        return '4A' if age > 14
        return '4P'
      when 'TDF/3TC/EFV'
        return '5A' if age > 14
        return '5P'
      when 'TDF/3TC+NVP'
        return '6A' if age > 14
        return '6P'
      when 'TDF/3TC+LPV/r'
        return '7A' if age > 14
        return '7P'
      when 'AZT/3TC+LPV/r'
        return '8A' if age > 14
        return '8P'
      when 'ABC/3TC+LPV/r'
        return '9A' if age > 14
        return '9P'
      else
        return 'UNKNOWN ANTIRETROVIRAL DRUG'
    end
  end
end
