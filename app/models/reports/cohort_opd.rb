class Reports::CohortOpd

  attr_accessor :start_date, :end_date

  def initialize(start_date, end_date, start_age, end_age, type)
    @start_date = "#{start_date} 00:00:00"
    @end_date = "#{end_date} 23:59:59"
    @start_age = start_age
    @end_age = end_age
    @type = type
    @outpatient_diagnosis_id = EncounterType.find_by_name("OUTPATIENT DIAGNOSIS").encounter_type_id
  	@opd_program_id = Program.find_by_name('OPD PROGRAM').id
  end

  def specified_period
    @range = [@start_date, @end_date]
  end

  def measles_u_5
  		concepts = ["MEASLES"]
			count_patient_with_concept(concepts, 0, 5)
  end

  def measles
  		concepts = ["MEASLES"]
			count_patient_with_concept(concepts)
  end

  def tb
  		concepts = ["TUBERCULOSIS"]
			count_patient_with_concept(concepts)
  end

  def upper_respiratory_infections 
  		concepts = ['UPPER RESPIRATORY TRACT INFECTION',
  								'ACUTE UPPER RESPIRATORY TRACT INFECTION',
  								'RECURRENT UPPER RESPIRATORY INFECTION (IE, BACTERIAL SINUSITIS)']
			count_patient_with_concept(concepts)
  end

  def pneumonia
  		concepts = ["%PNEUMONIA%"]
			count_patient_with_concept(concepts)
  end

  def pneumonia_u_5
  		concepts = ["%PNEUMONIA%"]
			count_patient_with_concept(concepts, 0, 5)
  end

  def asthma
  		concepts = ["%ASTHMA%"]
			count_patient_with_concept(concepts)
  end

  def lower_respiratory_infection
  		concepts = ["%LOWER%RESPIRATORY%INFECTION%"]
			count_patient_with_concept(concepts)
  end

  def cholera
  		concepts = ["%CHOLERA%"]
			count_patient_with_concept(concepts)
  end

  def cholera_u_5
  		concepts = ["%CHOLERA%"]
			count_patient_with_concept(concepts, 0, 5)
  end

  def dysentery
  		concepts = ["%DYSENTERY%"]
			count_patient_with_concept(concepts)
  end

  def dysentery_u_5
  		concepts = ["%DYSENTERY%"]
			count_patient_with_concept(concepts, 0, 5)
  end

  def diarrhoea
  		concepts = ["%DIARRHOEA%", "%DIARRHEA%"]
			count_patient_with_concept(concepts)
  end

  def diarrhoea_u_5
  		concepts = ["%DIARRHOEA%", "%DIARRHEA%"]
			count_patient_with_concept(concepts, 0, 5)
  end

  def anaemia
  		concepts = ["%ANAEMIA%"]
			count_patient_with_concept(concepts)
  end

  def malnutrition
  		concepts = ["%MALNUTRITION%"]
			count_patient_with_concept(concepts)
  end

  def goitre
  		concepts = ["%GOITRE%"]
			count_patient_with_concept(concepts)
  end

  def hypertension
  		concepts = ["%HYPERTENSION%"]
			count_patient_with_concept(concepts)
  end

  def heart
  		concepts = ["%HEART%"]
			count_patient_with_concept(concepts)
  end

  def acute_eye_infection
  		concepts = ["%ACUTE%EYE%INFECTION%"]
			count_patient_with_concept(concepts)
  end

  def epilepsy
  		concepts = ["%EPILEPSY%"]
			count_patient_with_concept(concepts)
  end

  def dental_decay
			count_patient_with_concept(["%DENTAL%DECAY%"])
  end

  def other_dental_conditions
  		concepts = ["DENTAL PAIN", "DENTAL ABSCESS", "DENTAL DISORDERS", "OTHER ORAL CONDITIONS"]
			count_patient_with_concept(concepts)
  end

  def scabies
  		concepts = ["%SCABIES%"]
			count_patient_with_concept(concepts)
  end

  def skin
  		concepts = ["%SKIN%"]
			count_patient_with_concept(concepts)
  end

  def malaria
  		concepts = ["%MALARIA%"]
			count_patient_with_concept(concepts)
  end

  def sti
  		concepts = ["GONORRHEA", "GONORRHOEAE", "SYPHILIS", "SEXUALLY TRANSMITTED INFECTION"]
			count_patient_with_concept(concepts)
  end

  def bilharzia
  		concepts = ["%BILHARZIA%"]
			count_patient_with_concept(concepts)
  end

  def chicken_pox
  		concepts = ["%CHICKEN%POX%"]
			count_patient_with_concept(concepts)
  end

  def intestinal_worms
  		concepts = ["%INTESTINAL%WORMS%"]
			count_patient_with_concept(concepts)
  end

  def jaundice
  		concepts = ["JAUNDICE AND INFECTIVE HEPATITIS"]
			count_patient_with_concept(concepts)
  end

  def meningitis
  		concepts = ["%MENINGITIS%"]
			count_patient_with_concept(concepts)
  end

  def typhoid
  		concepts = ["%TYPHOID%FEVER%"]
			count_patient_with_concept(concepts)
  end

  def rabies
  		concepts = ["%RABIES%"]
			count_patient_with_concept(concepts)
  end

  def communicable_diseases
  		concepts = ["ALL OTHER COMMUNICABLE DISEASES"]
			count_patient_with_concept(concepts)
  end

  def gynaecological_disorders
  		concepts = ["GYNAECOLOGICAL DISORDERS"]
			count_patient_with_concept(concepts)
  end

  def genito_urinary_infections
  		concepts = ["OTHER GENITO-URINARY TRACT INFECTION"]
			count_patient_with_concept(concepts)
  end

  def musculoskeletal_pains
  		concepts = ["%MUSCULOSKELETAL%PAIN%"]
			count_patient_with_concept(concepts)
  end

  def traumatic_conditions
  		concepts = ["TRAUMATIC CONDITIONS"]
			count_patient_with_concept(concepts)
  end

  def ear_infections
  		concepts = ["EAR INFECTION"]
			count_patient_with_concept(concepts)
  end

  def non_communicable_diseases
  		concepts = ["ALL OTHER NON-COMMUNICABLE DISEASES"]
			count_patient_with_concept(concepts)
  end

  def accident
  		concepts = ["ROAD TRAFFIC ACCIDENT"]
			count_patient_with_concept(concepts)
  end

  def diabetes
  		concepts = ["%DIABETES%"]
			count_patient_with_concept(concepts)
  end

  def surgicals
  		concepts = ["ALL OTHER SURGICAL CONDITIONS"]
			count_patient_with_concept(concepts)
  end
  
  def gastritis
  		concepts = ["GASTRITIS"]
			count_patient_with_concept(concepts)
  end
  
  def pud
  		concepts = ["PUD", "%ULCER%"]
			count_patient_with_concept(concepts)
  end
  
  def general
    result = []
    
    diagnoses = ConceptName.find_by_name("QECH OUTPATIENT DIAGNOSIS LIST").concept.concept_answers.collect{|c| c.answer.fullname}
    diagnoses.each{|diagnosis|
    	concepts = []
			concepts << diagnosis.to_s
      cases =  count_patient_with_concept(concepts)
      result << [diagnosis, cases]
    }
    result.sort_by{|arr| arr.last}.reverse rescue []
  end

  def opd_deaths
		 Person.count(:all,
									:include => {:patient => {:patient_programs=>
									 						 {:patient_states => {:program_workflow_state =>
									 						 {:concept => {:concept_names => {}}}}}}},
									:conditions => ["patient.patient_id IS NOT NULL
																	 AND patient_state.end_date IS NULL
																	 AND patient_state.start_date >= ? AND patient_state.start_date <= ?
																	 AND DATEDIFF(NOW(), person.birthdate)/365 >= ?
																	 AND DATEDIFF(NOW(), person.birthdate)/365 <= ?
									                 AND concept_name.name = 'Patient died'
									                 AND patient_program.program_id = ?",
									                 @start_date, @end_date, @start_age, @end_age,
									                 @opd_program_id]
								)
  end
  
	def count_patient_with_concept(params_array, start_age=nil, end_age=nil)		
			start_age = @start_age if start_age.nil?
			end_age = @end_age if end_age.nil?
			
			condition_string = "name LIKE \"#{params_array.pop}\" "
			params_array.each {|value| condition_string << "OR name LIKE \"#{value}\""}
			@ids = ConceptName.find_by_sql("SELECT *
																		 FROM concept_name
																		 WHERE #{condition_string} AND voided = 0"
																		 ).map{|c| c.concept_id}
																		 											 												 
			Encounter.find(:all,
										 :joins => [:type, :observations, [:patient => :person]],
										 :conditions => ["encounter_type = ? AND encounter.voided = 0 AND
																		value_coded IN (?) AND encounter_datetime >= ?
																		AND encounter_datetime <= ? AND DATEDIFF(NOW(), person.birthdate)/365 >= ?
																		AND DATEDIFF(NOW(), person.birthdate)/365 <= ?",
																		@outpatient_diagnosis_id, @ids, @start_date, @end_date,
																		start_age, end_age]
										).map{|e| e. patient_id}.uniq.size
	end

  def hiv_positive
  	concept_ids_hash = {}
  	encounter_type_id = EncounterType.find_by_name("UPDATE HIV STATUS").encounter_type_id
		ConceptName.find(:all,
										 :conditions =>["name IN ('HIV status', 'On ART', 'POSITIVE', 'Yes')"]
										 ).map{|c| concept_ids_hash[c.name.upcase]=c.concept_id}

		@cases = Encounter.find(:all,
														:joins => [:type, :observations, [:patient => :person]],
														:conditions => ["encounter_type = ? AND encounter.voided = 0 AND
																						(concept_id = ? OR concept_id = ?) AND (value_coded = ? OR value_coded = ?)
																						AND encounter_datetime >= ? AND encounter_datetime <= ?
																						AND DATEDIFF(NOW(), person.birthdate)/365 >= ? AND
																						DATEDIFF(NOW(), person.birthdate)/365 <= ? ",
																						encounter_type_id, concept_ids_hash["HIV STATUS"],
																						concept_ids_hash["ON ART"], concept_ids_hash["POSITIVE"],
																						concept_ids_hash["YES"], @start_date, @end_date, @start_age, @end_age]
														).map{|e| e. patient_id}.uniq.size
  end

  def attendance
		@cases = Encounter.find_by_sql(
												"SELECT patient_id, COUNT(patient_id), DATE_FORMAT(encounter_datetime,'%Y-%m-%d') enc_date 
												FROM encounter e
												LEFT OUTER JOIN person p ON p.person_id = e.patient_id 
												WHERE e.voided = 0 AND encounter_datetime >= '" + @start_date +"'
													AND encounter_datetime <= '" + @end_date + "'
													AND DATEDIFF(NOW(), p.birthdate)/365 >= " + @start_age + "
													AND DATEDIFF(NOW(), p.birthdate)/365 <= " + @end_age + "
												GROUP BY patient_id, enc_date
												ORDER BY patient_id ASC, COUNT(patient_id) DESC"
		).map{|e| e. patient_id}.uniq.size
  end
end
