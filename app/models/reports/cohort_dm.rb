class Reports::CohortDm

  attr_accessor :start_date, :end_date

# Initialize class
  def initialize(start_date, end_date)
    @start_date = "#{start_date} 00:00:00"
    @end_date = "#{end_date} 23:59:59"
  	@diabetes_program_id = Program.find_by_name('DIABETES PROGRAM').id
		@hypertensition_medication_id  = Concept.find_by_name("HYPERTENSION MEDICATION").id
		@diabetes_id                   = Concept.find_by_name("DIABETES MEDICATION").id
		@hypertensition_id             = Concept.find_by_name("HYPERTENSION").id


# Metformin And Glibenclamide
		# Patients on metformin and glibenclamide: up to end date
  	@ids_for_patients_on_metformin_and_glibenclamide_ever = Patient.find(:all,
													 :include =>{:orders => {:drug_order =>{:drug => {}}}},
													 :conditions => ['drug.name LIKE ? OR drug.name LIKE ?
													 									AND patient.date_created <= ?', "%metformin%",
													 									"%glibenclamide%", @end_date]
  							 					).map{|patient| patient.patient_id}.uniq

												
		# Patients on metformin and glibenclamide: between @start_date and @end_date
  	@ids_for_patients_on_metformin_and_glibenclamide = Patient.find(:all,
													 :include =>{:orders => {:drug_order =>{:drug => {}}}},
													 :conditions => ['drug.name LIKE ? OR drug.name LIKE ?
													 									AND patient.date_created >= ? AND patient.date_created <= ?',
													 									"%metformin%", "%glibenclamide%",
													 									@start_date, @end_date]
  							 					).map{|patient| patient.patient_id}.uniq


# Insulin
  	@ids_for_patients_on_insulin_ever = ids_for_patient_on_drug_upto_end_date(@end_date, 'insulin')							 			 
  	@ids_for_patients_on_insulin = ids_for_patient_on_drug_btn_dates(@start_date, @end_date, 'insulin')

# Metformin
  	@ids_for_patients_on_metformin_ever = ids_for_patient_on_drug_upto_end_date(@end_date, 'metformin')  							 			 
  	@ids_for_patients_on_metformin = ids_for_patient_on_drug_btn_dates(@start_date, @end_date, 'metformin')
  	
# Glibenclamide
  	@ids_for_patients_on_glibenclamide_ever = ids_for_patient_on_drug_upto_end_date(@end_date, 'glibenclamide')  							 			 
  	@ids_for_patients_on_glibenclamide = ids_for_patient_on_drug_btn_dates(@start_date, @end_date, 'glibenclamide')

# Lente_insulin
  	@ids_for_patients_on_lente_insulin_ever = ids_for_patient_on_drug_upto_end_date(@end_date, 'lente', 'insulin')  							 			 
  	@ids_for_patients_on_lente_insulin = ids_for_patient_on_drug_btn_dates(@start_date, @end_date, 'lente', 'insulin')

# Soluble insulin ever
  	@ids_for_patients_on_soluble_insulin_ever = ids_for_patient_on_drug_upto_end_date(@end_date, 'soluble', 'insulin')  							 			 
  	@ids_for_patients_on_soluble_insulin = ids_for_patient_on_drug_btn_dates(@start_date, @end_date, 'soluble', 'insulin')
  	
# Complications
		@complications_hash_upto_end_date = Hash.new(0)
		@complications_hash_btn_dates = Hash.new(0)
		
		@complications_hash_upto_end_date = Patient.count(:all,
											:include => { :encounters => {:observations => {:answer_concept => {:concept_names => {}}}}},
											:conditions => ["patient.date_created <= ?", @end_date],
											:group => "concept_name.name")
											
		@complications_hash_btn_dates = Patient.count(:all,
											:include => { :encounters => {:observations => {:answer_concept => {:concept_names => {}}}}},
											:conditions => ["patient.date_created >= ? AND patient.date_created <= ?",
																			 @start_date, @end_date],
											:group => "concept_name.name")
  end

# Metformin
  # Model access test function
  def specified_period
    @range = [@start_date, @end_date]
  end

  # Get all patients registered in specified period
  def total_registered
		Patient.count( :all,
									:conditions => [" patient.date_created >= ?
																		AND patient.date_created <= ?
																		AND voided = 0", @start_date, @end_date]
								)

  end

  def total_adults_registered
		Patient.count(:all,
									:include => {:person =>{}},
									:conditions => ["patient.date_created >= ?
																		AND patient.date_created <= ? AND " +
																		"COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) >= 15
																		AND patient.voided = 0", @start_date, @end_date]
								)
  end

  def total_children_registered
		Patient.count(:all,
								 :include => {:person =>{}},
								 :conditions => ["patient.date_created >= ?
								 										AND patient.date_created <= ? AND " +
																		"COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 14
																		AND patient.voided = 0", @start_date, @end_date]
								 )
  end

  def total_men_registered
		Patient.count(:all,
									:include => {:person =>{}},
									:conditions => ["patient.date_created >= ? AND
																		patient.date_created <= ?
																		AND UCASE(person.gender) = ?
																		AND patient.voided = 0",
																		@start_date, @end_date, "M"]
								 )
  end

  def total_adult_men_registered
		Patient.count(:all,
									:include => {:person =>{}},
									:conditions => ["patient.date_created >= ?
																		AND patient.date_created <= ?
																		AND UCASE(person.gender) = ?
																		AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) >= 15
																		AND patient.voided = 0",
																		@start_date, @end_date, "M"]
									)
  end

  def total_boy_children_registered
		Patient.find(:all,
								 :include => {:person =>{}},
								 :conditions => ["patient.date_created >= ?
								 									AND patient.date_created <= ?
																	AND UCASE(person.gender) = ?
																	AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 14
																	AND patient.voided = 0",
																	@start_date, @end_date, "M"]
								)
  end

  def total_women_registered
		Patient.count(:all,
									:include => {:person =>{}},
									:conditions => ["patient.date_created >= ? AND
																		patient.date_created <= ?
																		AND UCASE(person.gender) = ?
																		AND patient.voided = 0",
																		@start_date, @end_date, "F"]
								 )
  end

  def total_adult_women_registered  
		Patient.count(:all,
									:include => {:person =>{}},
									:conditions => ["patient.date_created >= ?
																		AND patient.date_created <= ?
																		AND UCASE(person.gender) = ?
																		AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) >= 15
																		AND patient.voided = 0",
																		@start_date, @end_date, "F"]
									)
  end

  def total_girl_children_registered
		Patient.count(:all,
								 :include => {:person =>{}},
								 :conditions => ["patient.date_created >= ?
								 									AND patient.date_created <= ?
																	AND UCASE(person.gender) = ?
																	AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 14
																	AND patient.voided = 0",
																	@start_date, @end_date, "F"]
								)
  end

  # Get all patients ever registered
  def total_ever_registered
		Patient.count(:all,
									:conditions => ["patient.voided = 0
																		AND patient.date_created <= ?", @end_date]
									)
  end

  def total_adults_ever_registered
		Patient.count(:all,
								 :include => {:person =>{}},
								 :conditions => ["COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) >= 15
								 									AND patient.voided = 0 AND patient.date_created <= ?",
								 									@end_date]
								)
  end

  def total_children_ever_registered       
		Patient.count(:all,
								 :include => {:person =>{}},
								 :conditions => ["COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 14
								 									AND patient.voided = 0 AND patient.date_created <= ?",
								 									@end_date]
								)
  end

  def total_men_ever_registered
    Patient.count(:all,
    							:include => {:person =>{}},
    							:conditions => ["person.gender = ?
    																AND patient.voided = 0
    																AND patient.date_created <= ?",
    																"M", @end_date])
  end

  def total_adult_men_ever_registered
		Patient.count(:all,
									:include => {:person =>{}},
									:conditions => ["person.gender = ?
																		AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) >= 15
																		AND patient.voided = 0
																		AND patient.date_created <= ?", "M", @end_date])
  end

  def total_boy_children_ever_registered
		Patient.count(:all,
									:include => {:person =>{}},
									:conditions => ["person.gender = ?
																		AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 14
																		AND patient.voided = 0
																		AND patient.date_created <= ?", "M", @end_date])
  end

  def total_women_ever_registered
    Patient.count(:all,
    							:include => {:person =>{}},
    							:conditions => ["person.gender = ?
    																AND patient.voided = 0
    																AND patient.date_created <= ?",
    																"F", @end_date])
  end

  def total_adult_women_ever_registered
		Patient.count(:all,
									:include => {:person =>{}},
									:conditions => ["person.gender = ?
																		AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) >= 15
																		AND patient.voided = 0
																		AND patient.date_created <= ?", "F", @end_date])
  end

  def total_girl_children_ever_registered
		Patient.count(:all,
									:include => {:person =>{}},
									:conditions => ["person.gender = ?
																		AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 14
																		AND patient.voided = 0
																		AND patient.date_created <= ?", "F", @end_date])
  end

  # Oral Treatments
  def oral_treatments_ever												 
   (@ids_for_patients_on_metformin_and_glibenclamide_ever - @ids_for_patients_on_insulin_ever).size
  end

  def oral_treatments											 
   (@ids_for_patients_on_metformin_and_glibenclamide -@ids_for_patients_on_insulin).size
  end

  # Insulin
  def insulin_ever                                        
   (@ids_for_patients_on_insulin_ever - @ids_for_patients_on_metformin_and_glibenclamide_ever).size
  end

  def insulin
   (@ids_for_patients_on_insulin - @ids_for_patients_on_metformin_and_glibenclamide).size
  end

  # Oral and Insulin
  def oral_and_insulin_ever
   (@ids_for_patients_on_insulin_ever & @ids_for_patients_on_metformin_and_glibenclamide_ever).size
  end

  def oral_and_insulin
   (@ids_for_patients_on_insulin & @ids_for_patients_on_metformin_and_glibenclamide).size
  end

  # Metformin
  def metformin_ever
			@ids_for_patients_on_metformin_ever.size
  end

  def metformin
			@ids_for_patients_on_metformin.size
  end

  # Glibenclamide
  def glibenclamide_ever
		@ids_for_patients_on_glibenclamide_ever.size
  end

  def glibenclamide
		@ids_for_patients_on_glibenclamide.size
  end

  # Lente Insulin
  def lente_insulin_ever
			@ids_for_patients_on_lente_insulin_ever.size
  end

  def lente_insulin
		@ids_for_patients_on_lente_insulin.size
  end

  # Soluble Insulin
  def soluble_insulin_ever
  	@ids_for_patients_on_soluble_insulin_ever.size
  end

  def soluble_insulin
  	@ids_for_patients_on_soluble_insulin.size
  end

  # Background Retinopathy
  def background_retinapathy_ever
		@complications_hash_upto_end_date['Background retinopathy'].to_i
  end

  def background_retinapathy
		@complications_hash_btn_dates['Background retinopathy'].to_i
  end

  # Ploriferative Retinopathy
  def ploriferative_retinapathy_ever
		@complications_hash_upto_end_date['Ploriferative retinopathy'].to_i
  end

  def ploriferative_retinapathy
		@complications_hash_btn_dates['Ploriferative retinopathy'].to_i
  end

  # End Stage Retinopathy
  def end_stage_retinapathy_ever
		@complications_hash_upto_end_date['End stage disease'].to_i
  end

  def end_stage_retinapathy
		@complications_hash_btn_dates['End stage disease'].to_i
  end

  # Cataract
  def cataracts_ever
		@complications_hash_upto_end_date['Cataract'].to_i
  end

  def cataracts
		@complications_hash_btn_dates['Cataract'].to_i
  end

  # Cataract
  def macrovascular_ever
		@complications_hash_upto_end_date['Myocardial infarction'].to_i +
		@complications_hash_upto_end_date['Angina'].to_i +
		@complications_hash_upto_end_date['Peripheral vascular disease'].to_i +
		@complications_hash_upto_end_date['Stroke'].to_i
  end

  def macrovascular
		@complications_hash_btn_dates['Myocardial infarction'].to_i +
		@complications_hash_btn_dates['Angina'].to_i +
		@complications_hash_btn_dates['Peripheral vascular disease'].to_i +
		@complications_hash_btn_dates['Stroke'].to_i
  end

  # No complications
  def no_complications_ever

    bgretinopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'BACKGROUND RETINOPATHY')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    plretinopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'PLORIFERATIVE RETINOPATHY')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    esretinopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'END STAGE DISEASE')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    cataract = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'CATARACT')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    pvd = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  WHERE value_coded IN (SELECT concept_id FROM concept_name \
                                      WHERE name = 'MYOCARDIAL INFARCTION' OR name = 'ANGINA' \
                                      OR name = 'STROKE' OR name = 'PERIPHERAL VASCULAR DISEASE')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    maculopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'MACULOPATHY') OR UCASE(value_text) = 'MACULOPATHY'").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    numbness = Order.find_by_sql("SELECT DISTINCT person_id FROM obs WHERE value_coded = \
                                      (SELECT concept_id FROM concept_name where name = 'NUMBNESS SYMPTOMS') \
                                        AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG'))").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    amputation = Order.find_by_sql("SELECT DISTINCT person_id FROM obs WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'AMPUTATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG'))").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    ulcers = Order.find_by_sql("SELECT DISTINCT person_id FROM obs WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'CURRENT FOOT ULCERATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                      ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG'))").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    creatinine = Order.find_by_sql("SELECT DISTINCT person_id, value_numeric FROM obs \
                                    WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                      WHERE name = 'CREATININE') AND COALESCE(value_numeric, 0) >= 1.2").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    urine = Order.find_by_sql("SELECT DISTINCT person_id FROM obs WHERE concept_id = \
                                      (SELECT concept_id FROM concept_name WHERE name = 'URINE PROTEIN') \
                                          AND value_coded IN (SELECT concept_id FROM concept_name
                                          WHERE name IN ('+', '++', '+++', '++++', 'trace') AND locale = 'en')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    @orders = Order.find_by_sql("SELECT DISTINCT patient_id FROM patient WHERE NOT patient_id IN \
                                (" + (bgretinopathy.length > 0 ? bgretinopathy : "0") +  ") AND NOT patient_id IN (" +
        (plretinopathy.length > 0 ? plretinopathy : "0") + ")  AND NOT patient_id IN (" +
        (esretinopathy.length > 0 ? esretinopathy : "0") + ") AND NOT patient_id IN (" +
        (cataract.length > 0 ? cataract : "0") + ") AND NOT patient_id IN (" +
        (pvd.length > 0 ? pvd : "0") + ") AND NOT patient_id IN (" +
        (maculopathy.length > 0 ? maculopathy : "0") + ") AND NOT patient_id IN (" +
        (numbness.length > 0 ? numbness : "0") + ") AND NOT patient_id IN (" +
        (amputation.length > 0 ? amputation : "0") + ") AND NOT patient_id IN (" +
        (ulcers.length > 0 ? ulcers : "0") + ") AND NOT patient_id IN (" +
        (creatinine.length > 0 ? creatinine : "0") + ") AND NOT patient_id IN (" +
        (urine.length > 0 ? urine : "0") + ") AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0").length
  end

  def no_complications

    bgretinopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'BACKGROUND RETINOPATHY')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    plretinopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'PLORIFERATIVE RETINOPATHY')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    esretinopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'END STAGE DISEASE')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    cataract = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'CATARACT')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    pvd = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded IN (SELECT concept_id FROM concept_name \
                                      WHERE name = 'MYOCARDIAL INFARCTION' OR name = 'ANGINA' \
                                      OR name = 'STROKE' OR name = 'PERIPHERAL VASCULAR DISEASE')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    maculopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'MACULOPATHY') OR UCASE(value_text) = 'MACULOPATHY'
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    numbness = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE value_coded = \
                                      (SELECT concept_id FROM concept_name where name = 'NUMBNESS SYMPTOMS') \
                                        AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG'))
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    amputation = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'AMPUTATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG'))
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    ulcers = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'CURRENT FOOT ULCERATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                      ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG'))
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    creatinine = Order.find_by_sql("SELECT DISTINCT person_id, value_numeric FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                      WHERE name = 'CREATININE') AND COALESCE(value_numeric, 0) >= 1.2
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    urine = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE concept_id = \
                                      (SELECT concept_id FROM concept_name WHERE name = 'URINE PROTEIN') \
                                          AND value_coded IN (SELECT concept_id FROM concept_name
                                          WHERE name IN ('+', '++', '+++', '++++', 'trace') AND locale = 'en')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    @orders = Order.find_by_sql("SELECT DISTINCT patient_id FROM patient WHERE NOT patient_id IN \
                                (" + (bgretinopathy.length > 0 ? bgretinopathy : "0") +  ") AND NOT patient_id IN (" +
        (plretinopathy.length > 0 ? plretinopathy : "0") + ")  AND NOT patient_id IN (" +
        (esretinopathy.length > 0 ? esretinopathy : "0") + ") AND NOT patient_id IN (" +
        (cataract.length > 0 ? cataract : "0") + ") AND NOT patient_id IN (" +
        (pvd.length > 0 ? pvd : "0") + ") AND NOT patient_id IN (" +
        (maculopathy.length > 0 ? maculopathy : "0") + ") AND NOT patient_id IN (" +
        (numbness.length > 0 ? numbness : "0") + ") AND NOT patient_id IN (" +
        (amputation.length > 0 ? amputation : "0") + ") AND NOT patient_id IN (" +
        (ulcers.length > 0 ? ulcers : "0") + ") AND NOT patient_id IN (" +
        (creatinine.length > 0 ? creatinine : "0") + ") AND NOT patient_id IN (" +
        (urine.length > 0 ? urine : "0") + ")
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").length
  end

  # Nephropathy: Urine Protein
  def urine_protein_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                      WHERE concept_id = \
                                      (SELECT concept_id FROM concept_name WHERE name = 'URINE PROTEIN') \
                                          AND value_coded IN (SELECT concept_id FROM concept_name
                                          WHERE name IN ('+', '++', '+++', '++++', 'trace') AND locale = 'en') AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0").length
  end

  def urine_protein
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                       WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'URINE PROTEIN') \
                                          AND value_coded IN (SELECT concept_id FROM concept_name
                                          WHERE name IN ('+', '++', '+++', '++++', 'trace') AND locale = 'en')\
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").length
  end

  # Nephropathy: Raised Creatinine >= 1.2mg/dl
  def creatinine_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id, value_numeric FROM obs \
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                      WHERE name = 'CREATININE') AND COALESCE(value_numeric, 0) >= 1.2 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0").length
  end

  def creatinine
    @orders = Order.find_by_sql("SELECT DISTINCT person_id, value_numeric FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                      WHERE name = 'CREATININE') AND COALESCE(value_numeric, 0) >= 1.2 \
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").length
  end

  # Neuropathy: Numbness Symptoms
  def numbness_symptoms_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE value_coded = \
                                      (SELECT concept_id FROM concept_name where name = 'NUMBNESS SYMPTOMS') \
                                        AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG')) AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0").length
  end

  def numbness_symptoms
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE value_coded = \
                                      (SELECT concept_id FROM concept_name where name = 'NUMBNESS SYMPTOMS') \
                                        AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG')) \
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").length
  end

  # Neuropathy: Amputation
  def amputation_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'AMPUTATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG')) AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0").length
  end

  def amputation
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'AMPUTATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG')) \
                                      AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").length
  end

  # Neuropathy: Current Foot Ulceration
  def current_foot_ulceration_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'CURRENT FOOT ULCERATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                      ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG')) AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0").length
  end

  def current_foot_ulceration
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'CURRENT FOOT ULCERATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                      ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG')) \
                                      AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").length
  end

  # TB After Diabetes
  def tb_after_diabetes_ever
    @orders = Order.find_by_sql("SELECT DISTINCT v1.person_id FROM \
                                    (SELECT person_id, value_datetime FROM obs \
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                      WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                        WHERE name = 'DIABETES DIAGNOSIS DATE') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v1,
                                    (SELECT person_id, value_datetime FROM obs o  \
                                      LEFT OUTER JOIN patient ON patient.patient_id = o.person_id \
                                      WHERE concept_id = (SELECT concept_id FROM concept_name WHERE \
                                       name = 'DIAGNOSIS DATE') AND obs_group_id IN (SELECT obs_id FROM obs s WHERE \
                                        concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?')) \
                                      AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v2
                                      WHERE v1.person_id = v2.person_id AND v1.value_datetime <= v2.value_datetime").length
  end

  def tb_after_diabetes
    @orders = Order.find_by_sql("SELECT v1.person_id FROM \
                                    (SELECT * FROM obs WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                        WHERE name = 'DIABETES DIAGNOSIS DATE')) AS v1, \
                                    (SELECT * FROM obs o WHERE concept_id = (SELECT concept_id FROM concept_name WHERE \
                                       name = 'DIAGNOSIS DATE') AND obs_group_id IN (SELECT obs_id FROM obs s WHERE \
                                        concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?'))) AS v2, \
                                    patient WHERE v1.person_id = v2.person_id AND v1.value_datetime <= v2.value_datetime \
                                      AND patient.patient_id = v1.person_id AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length
  end

  # TB After Diabetes
  def tb_before_diabetes_ever
    @orders = Order.find_by_sql("SELECT DISTINCT v1.person_id FROM \
                                    (SELECT person_id, value_datetime FROM obs \
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                      WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                        WHERE name = 'DIABETES DIAGNOSIS DATE') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v1,
                                    (SELECT person_id, value_datetime FROM obs o  \
                                      LEFT OUTER JOIN patient ON patient.patient_id = o.person_id \
                                      WHERE concept_id = (SELECT concept_id FROM concept_name WHERE \
                                       name = 'DIAGNOSIS DATE') AND obs_group_id IN (SELECT obs_id FROM obs s WHERE \
                                        concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?')) \
                                      AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v2
                                      WHERE v1.person_id = v2.person_id AND v1.value_datetime > v2.value_datetime").length
  end

  def tb_before_diabetes
    @orders = Order.find_by_sql("SELECT v1.person_id FROM \
                                    (SELECT * FROM obs WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                        WHERE name = 'DIABETES DIAGNOSIS DATE')) AS v1, \
                                    (SELECT * FROM obs o WHERE concept_id = (SELECT concept_id FROM concept_name WHERE \
                                       name = 'DIAGNOSIS DATE') AND obs_group_id IN (SELECT obs_id FROM obs s WHERE \
                                        concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?'))) AS v2, \
                                    patient WHERE v1.person_id = v2.person_id AND v1.value_datetime > v2.value_datetime \
                                      AND patient.patient_id = v1.person_id AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length
  end

  def no_tb_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id \
                              FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?') AND value_coded IN \
                              (SELECT concept_id FROM concept_name WHERE name = 'NO') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' ").length
  end

  def no_tb
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id \
                              FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?') AND value_coded IN \
                              (SELECT concept_id FROM concept_name WHERE name = 'NO') AND \
                               DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
                                "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0").length
  end

  def tb_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id \
                              FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?') AND value_coded IN \
                              (SELECT concept_id FROM concept_name WHERE name = 'YES') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' ").length
  end

  def tb
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id \
                              FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?') AND value_coded IN \
                              (SELECT concept_id FROM concept_name WHERE name = 'YES') AND \
                               DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
                                "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0").length
  end

  def tb_known_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id \
                              FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' ").length
  end

  def tb_known
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id \
                              FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?') AND \
                               DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
                                "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0").length
  end

  def tb_unkown_ever
    
    tb = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id \
                              FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")
    
    @orders = Order.find_by_sql("SELECT DISTINCT patient_id FROM patient WHERE NOT patient_id IN \
                                (" + (tb.length > 0 ? tb : "0") +  ") AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length
  end

  def tb_unkown

    tb = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id \
                              FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")
    
    @orders = Order.find_by_sql("SELECT DISTINCT patient_id FROM patient WHERE NOT patient_id IN \
                                (" + (tb.length > 0 ? tb : "0") +  ")
                                AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
                                "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0").length
  end

  # HIV Status: Reactive Not on ART
  def reactive_not_on_art_ever
    @orders = Order.find_by_sql("SELECT DISTINCT v1.person_id FROM
                                      (SELECT person_id FROM obs LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                        WHERE concept_id = (SELECT concept_id FROM concept_name \
                                          WHERE name = 'ON ART') AND value_coded IN (SELECT concept_id FROM concept_name \
                                            WHERE name = 'NO') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v1,
                                      (SELECT person_id FROM obs  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                        WHERE value_coded = (SELECT concept_id FROM concept_name \
                                        WHERE name = 'POSITIVE') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v2 WHERE v1.person_id = v2.person_id").length
  end

  def reactive_not_on_art
    @orders = Order.find_by_sql("SELECT DISTINCT v1.person_id FROM
                                      (SELECT * FROM obs WHERE concept_id = (SELECT concept_id FROM concept_name \
                                          WHERE name = 'ON ART') AND value_coded IN (SELECT concept_id FROM concept_name \
                                            WHERE name = 'NO')) AS v1,
                                      (SELECT * FROM obs WHERE value_coded = (SELECT concept_id FROM concept_name \
                                        WHERE name = 'POSITIVE')) AS v2, \
                                    patient WHERE v1.person_id = v2.person_id \
                                      AND patient.patient_id = v1.person_id AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length
  end

  # HIV Status: Reactive  on ART
  def reactive_on_art_ever
    @orders = Order.find_by_sql("SELECT DISTINCT v1.person_id FROM
                                      (SELECT person_id FROM obs  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                        WHERE concept_id = (SELECT concept_id FROM concept_name \
                                          WHERE name = 'ON ART') AND value_coded IN (SELECT concept_id FROM concept_name \
                                            WHERE name = 'YES') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v1,
                                      (SELECT person_id FROM obs  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                        WHERE value_coded = (SELECT concept_id FROM concept_name \
                                        WHERE name = 'POSITIVE') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v2 WHERE v1.person_id = v2.person_id").length
  end

  def reactive_on_art
    @orders = Order.find_by_sql("SELECT DISTINCT v1.person_id FROM
                                      (SELECT * FROM obs WHERE concept_id = (SELECT concept_id FROM concept_name \
                                          WHERE name = 'ON ART') AND value_coded IN (SELECT concept_id FROM concept_name \
                                            WHERE name = 'YES')) AS v1,
                                      (SELECT * FROM obs WHERE value_coded = (SELECT concept_id FROM concept_name \
                                        WHERE name = 'POSITIVE')) AS v2, \
                                    patient WHERE v1.person_id = v2.person_id \
                                      AND patient.patient_id = v1.person_id AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length
  end

  # HIV Status: Non Reactive
  def non_reactive_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                        WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name WHERE name = 'NEGATIVE') and concept_id = \
                                      (SELECT concept_id FROM concept_name WHERE name = 'HIV STATUS') AND \
                                        DATEDIFF(NOW(), obs_datetime)/365 < 1 AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length
  end

  def non_reactive
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs  \
                                    LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE value_coded = (SELECT concept_id FROM concept_name WHERE name = 'NEGATIVE') AND \
                                    concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV STATUS') AND \
                                        DATEDIFF(NOW(), obs_datetime)/365 < 1 \
                                      AND patient.patient_id = obs.person_id AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").length
  end

  # HIV Status: Unknown
  def unknown_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                        WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name WHERE name = 'NEGATIVE') and concept_id = \
                                      (SELECT concept_id FROM concept_name WHERE name = 'HIV STATUS') AND \
                                        DATEDIFF(NOW(), obs_datetime)/365 > 1 AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length
  end

  def unknown
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs  \
                                    LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE value_coded = (SELECT concept_id FROM concept_name WHERE name = 'NEGATIVE') AND \
                                    concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV STATUS') \
                                      AND patient.patient_id = obs.person_id AND DATEDIFF(NOW(), obs_datetime)/365 > 1 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").length
  end

  # Outcome
  def dead_ever
  	@dead_ever = Person.find(:all, :conditions => ["person_id IN (SELECT patient_id FROM patient) AND dead = 1 AND DATE(death_date) <= DATE('#{@end_date}')"]).length
  end

  def dead
  	@dead = Person.find(:all,
  											:conditions => ["person_id IN (SELECT patient_id FROM patient) AND dead = 1 AND DATE(death_date) >= DATE('#{@start_date}') AND DATE(death_date) <= DATE('#{@end_date}')"]).length
  end

  def alive_ever
  	Person.find(:all, :conditions => ["person_id IN (SELECT patient_id FROM patient) AND dead = 0 AND DATE(date_created) <= DATE('#{@end_date}')"]).length
  end

  def alive
  	Person.find(:all,
								:conditions => ["person_id IN (SELECT patient_id FROM patient) AND dead = 0 AND DATE(date_created) >= DATE('#{@start_date}') AND DATE(date_created) <= DATE('#{@end_date}')"]).length
 end

  def transfer_out_ever
			sql = "SELECT DISTINCT p.patient_id 
						FROM patient p
								 LEFT JOIN patient_program pp
								 ON p.patient_id = pp.patient_id
								 					 LEFT JOIN patient_state st
								 					 ON pp.patient_program_id = st.patient_program_id
								 					 						LEFT JOIN program_workflow_state pws
								 					 						ON st.state = pws.program_workflow_state_id
								 					 											LEFT JOIN concept_name cn ON pws.concept_id = cn.concept_id
						WHERE st.end_date IS NULL AND cn.name = 'Patient transferred out' AND st.voided = 0
									AND DATE_FORMAT(st.date_created, '%Y-%m-%d') <= '#{@end_date}'
									AND pp.program_id = #{@diabetes_program_id}"

			Patient.find_by_sql(sql).length
  end

  def transfer_out
			sql = "SELECT DISTINCT p.patient_id 
						FROM patient p
								 LEFT JOIN patient_program pp
								 ON p.patient_id = pp.patient_id
								 					 LEFT JOIN patient_state st
								 					 ON pp.patient_program_id = st.patient_program_id
								 					 						LEFT JOIN program_workflow_state pws
								 					 						ON st.state = pws.program_workflow_state_id
								 					 											LEFT JOIN concept_name cn ON pws.concept_id = cn.concept_id
						WHERE st.end_date IS NULL AND cn.name = 'Patient transferred out' AND st.voided = 0
									AND DATE_FORMAT(st.date_created, '%Y-%m-%d') >= '#{@start_date}' AND DATE_FORMAT(st.date_created, '%Y-%m-%d') <= '#{@end_date}' 
									AND pp.program_id = #{@diabetes_program_id}"

			Patient.find_by_sql(sql).length
  end

  def stopped_treatment_ever
			sql = "SELECT DISTINCT p.patient_id 
						FROM patient p
								 LEFT JOIN patient_program pp
								 ON p.patient_id = pp.patient_id
								 					 LEFT JOIN patient_state st
								 					 ON pp.patient_program_id = st.patient_program_id
								 					 						LEFT JOIN program_workflow_state pws
								 					 						ON st.state = pws.program_workflow_state_id
								 					 											LEFT JOIN concept_name cn ON pws.concept_id = cn.concept_id
						WHERE st.end_date IS NULL AND cn.name = 'TREATMENT STOPPED' AND st.voided = 0
									AND DATE_FORMAT(st.date_created, '%Y-%m-%d') <= '#{@end_date}'
									AND pp.program_id = #{@diabetes_program_id}"

			Patient.find_by_sql(sql).length
  end

  def stopped_treatment
			sql = "SELECT DISTINCT p.patient_id 
						FROM patient p
								 LEFT JOIN patient_program pp
								 ON p.patient_id = pp.patient_id
								 					 LEFT JOIN patient_state st
								 					 ON pp.patient_program_id = st.patient_program_id
								 					 						LEFT JOIN program_workflow_state pws
								 					 						ON st.state = pws.program_workflow_state_id
								 					 											LEFT JOIN concept_name cn ON pws.concept_id = cn.concept_id
						WHERE st.end_date IS NULL AND cn.name = 'TREATMENT STOPPED' AND st.voided = 0
									AND DATE_FORMAT(st.date_created, '%Y-%m-%d') >= '#{@start_date}' AND DATE_FORMAT(st.date_created, '%Y-%m-%d') <= '#{@end_date}' 
									AND pp.program_id = #{@diabetes_program_id}"
									
			Patient.find_by_sql(sql).length
  end

  # Treatment (Alive and Even Defaulters)
  def on_diet_ever
    @orders = Order.find_by_sql("SELECT DISTINCT orders.patient_id FROM orders \
                                  LEFT OUTER JOIN patient ON patient.patient_id = orders.patient_id \
                                  WHERE NOT order_id IN \
                                    (SELECT order_id FROM drug_order \
                                      WHERE drug_inventory_id IN \
                                        (SELECT drug_id FROM drug d WHERE (name LIKE '%lente%' AND name LIKE '%insulin%') OR \
                                        (name LIKE '%soluble%' AND name LIKE '%insulin%') OR (name LIKE '%glibenclamide%') OR \
                                        (name LIKE '%metformin%'))) \
                                    AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length
  end

  def on_diet
    @orders = Order.find_by_sql("SELECT DISTINCT orders.patient_id FROM orders LEFT OUTER JOIN patient ON \
                                        patient.patient_id = orders.patient_id WHERE NOT order_id IN \
                                    (SELECT order_id FROM drug_order \
                                      WHERE drug_inventory_id IN \
                                        (SELECT drug_id FROM drug d WHERE (name LIKE '%lente%' AND name LIKE '%insulin%') OR \
                                        (name LIKE '%soluble%' AND name LIKE '%insulin%') OR (name LIKE '%glibenclamide%') OR \
                                        (name LIKE '%metformin%'))) AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + 
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length
  end

  # Outcome: Defaulters
  def defaulters_ever
  @orders = Order.find_by_sql("SELECT orders.patient_id FROM orders \
                                LEFT OUTER JOIN patient ON patient.patient_id = orders.patient_id \
                                WHERE DATEDIFF('#{@end_date}', auto_expire_date)/30 > 6 \
                                  AND patient.voided = 0 AND \
                                      DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'  \
																			AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
																			concept_set IN (#{@diabetes_id}, #{@hypertensition_id}, #{@hypertensition_medication_id})) \
                                  GROUP BY patient_id").length
  end

  def defaulters
    @orders = Order.find_by_sql("SELECT orders.patient_id FROM orders LEFT OUTER JOIN patient ON \
                                        patient.patient_id = orders.patient_id WHERE DATEDIFF('#{@end_date}', auto_expire_date)/30 > 6 \
                                        AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0 \
																			AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
																			concept_set IN (#{@diabetes_id}, #{@hypertensition_id}, #{@hypertensition_medication_id})) \
                                          GROUP BY patient_id").length
  end

  # Maculopathy
  def maculopathy_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'MACULOPATHY') OR UCASE(value_text) = 'MACULOPATHY' \
                                    AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length
  end

  def maculopathy
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
		                                 WHERE value_coded = (SELECT concept_id FROM concept_name \
		                                    WHERE name = 'MACULOPATHY') OR UCASE(value_text) = 'MACULOPATHY' \
		                                  AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
		      "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").length
  end
  
  

  def ids_for_patient_on_drug_upto_end_date(end_date, drug_name, second_name=nil)
  		ids = []
  		if second_name.nil?
				ids = Patient.find(:all,
										 :include =>{:orders => {:drug_order =>{:drug => {}}}},
										 :conditions => ['drug.name LIKE ? AND patient.date_created <= ?',
										 									'%' + drug_name + '%', end_date]
										 ).map{|patient| patient.patient_id}.uniq
  		else
				ids = Patient.find(:all,
										 :include =>{:orders => {:drug_order =>{:drug => {}}}},
										 :conditions => ['drug.name LIKE ? AND drug.name LIKE ? AND patient.date_created <= ?',
										 									'%' + drug_name + '%', '%' + second_name + '%', end_date]
										 ).map{|patient| patient.patient_id}.uniq
  		end
  		ids
  end
  
  def ids_for_patient_on_drug_btn_dates(start_date, end_date, drug_name, second_name=nil)
		ids = []
  	if second_name.nil?
			ids = Patient.find( :all,
										 :include =>{:orders => {:drug_order =>{:drug => {}}}},
										 :conditions => ['drug.name LIKE ? AND patient.date_created >= ?
										 									AND patient.date_created <= ?', '%' + drug_name + '%',
										 									start_date, end_date]
										 ).map{|patient| patient.patient_id}.uniq
		else
			ids = Patient.find( :all,
										 :include =>{:orders => {:drug_order =>{:drug => {}}}},
										 :conditions => ['drug.name LIKE ? AND drug.name LIKE ? AND patient.date_created >= ?
										 									AND patient.date_created <= ?', '%' + drug_name + '%',
										 									'%' + second_name + '%', start_date, end_date]
										 ).map{|patient| patient.patient_id}.uniq		
		end
		ids
  end
  
  def ids_for_patients_with_complication_upto_end_date(complication, end_date)
		Patient.find(:all,
							 :include => { :encounters => {:observations => {:answer_concept => {:concept_names => {}}}}},
							 :conditions => ["concept_name.name = ?
							 									AND patient.date_created <= ?",complication,  end_date]
							).map{|patient| patient.patient_id}.uniq
	end
	
	def ids_for_patients_with_complication_btn_dates(complication, start_date, end_date)
		Patient.find(:all,
									 :include => { :encounters => {:observations => {:answer_concept => {:concept_names => {}}}}},
									 :conditions => ["concept_name.name = ?
									 									AND patient.date_created >= ? AND patient.date_created <= ?",
									 									complication, start_date, end_date]
									).map{|patient| patient.patient_id}.uniq
	end
end
