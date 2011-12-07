module MedicationService

	def self.arv(drug)
		arv_drugs.map(&:concept_id).include?(drug.concept_id)
	end

	def self.arv_drugs
		arv_concept       = ConceptName.find_by_name("ANTIRETROVIRAL DRUGS").concept_id
		arv_drug_concepts = ConceptSet.all(:conditions => ['concept_set = ?', arv_concept])
		arv_drug_concepts
	end

	def self.tb_medication(drug)
		tb_drugs.map(&:concept_id).include?(drug.concept_id)
	end

	def self.tb_drugs
		tb_medication_concept       = ConceptName.find_by_name("Tuberculosis treatment drugs").concept_id
		tb_medication_drug_concepts = ConceptSet.all(:conditions => ['concept_set = ?', tb_medication_concept])
		tb_medication_drug_concepts
	end
	
	def self.diabetes_medication(drug)
		diabetes_drugs.map(&:concept_id).include?(drug.concept_id)
	end	
	
	def self.diabetes_drugs
		diabetes_medication_concept       = ConceptName.find_by_name("DIABETES MEDICATION").concept_id
		diabetes_medication_drug_concepts = ConceptSet.all(:conditions => ['concept_set = ?', diabetes_medication_concept])
		diabetes_medication_drug_concepts
	end

  # Convert a list +Concept+s of +Regimen+s for the given +Patient+ <tt>age</tt>
  # into select options. See also +EncountersController#arv_regimen_answers+
	def self.regimen_options(regimen_concepts, age)
		options = regimen_concepts.map { |r|
			[r.concept_id, (r.concept_names.typed("SHORT").first ||
				r.concept_names.typed("FULLY_SPECIFIED").first).name]
		}
	
		suffixed_options = options.collect { |opt|
			opt_reg = Regimen.find(	:all,
									:select => 'regimen_index',
									:order => 'regimen_index',
									:conditions => ['concept_id = ?', opt[0]]).uniq.first
			if age >= 15
				suffix = "A"
			else
				suffix = "P"
			end

			#[opt[0], "#{opt_reg.regimen_index}#{suffix} - #{opt[1]}"]
			if opt_reg.regimen_index > -1
				["#{opt_reg.regimen_index}#{suffix} - #{opt[1]}", opt[0], opt_reg.regimen_index.to_i]
			else
				["#{opt[1]}", opt[0], opt_reg.regimen_index.to_i]
			end
		}.sort_by{|opt| opt[2]}
	end
	
  def self.current_orders(patient)
    encounter = current_treatment_encounter(patient)
    orders = encounter.orders.active
    orders
  end
  
  def self.current_treatment_encounter(patient)
    type = EncounterType.find_by_name("TREATMENT")
    encounter = patient.encounters.current.find_by_encounter_type(type.id)
    encounter ||= patient.encounters.create(:encounter_type => type.id)
  end

end
