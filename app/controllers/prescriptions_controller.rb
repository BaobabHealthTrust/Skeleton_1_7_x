class PrescriptionsController < ApplicationController
  # Is this used?
  def index
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @orders = @patient.orders.prescriptions.current.all rescue []
    @history = @patient.orders.prescriptions.historical.all rescue []
    redirect_to "/prescriptions/new?patient_id=#{params[:patient_id] || session[:patient_id]}" and return if @orders.blank?
    render :template => 'prescriptions/index', :layout => 'menu'
  end
  
  def new
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @patient_diagnoses = current_diagnoses(@patient.person.id)
    @current_weight = PatientService.get_patient_attribute_value(@patient, "current_weight")
		@current_height = PatientService.get_patient_attribute_value(@patient, "current_height")
  end
  
  def void	
    @order = Order.find(params[:order_id])
    @order.void
    flash.now[:notice] = "Order was successfully voided"
    if !params[:source].blank? && params[:source].to_s == 'advanced'
		redirect_to "/prescriptions/advanced_prescription?patient_id=#{params[:patient_id]}" and return
    else
    	index and return
   	end
  end
  
  def create
    @suggestions = params[:suggestion] || ['New Prescription']
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    unless params[:location]
      session_date = session[:datetime] || params[:encounter_datetime] || Time.now()
    else
      session_date = params[:encounter_datetime] #Use encounter_datetime passed during import
    end
    # set current location via params if given
    Location.current_location = Location.find(params[:location]) if params[:location]
    
    if params[:filter] and !params[:filter][:provider].blank?
      user_person_id = User.find_by_username(params[:filter][:provider]).person_id
    elsif params[:location] # migration
      user_person_id = params[:provider_id]
    else
      user_person_id = User.find_by_user_id(session[:user_id]).person_id
    end

    @encounter = PatientService.current_treatment_encounter( @patient, session_date, user_person_id)
    @diagnosis = Observation.find(params[:diagnosis]) rescue nil
    @suggestions.each do |suggestion|
      unless (suggestion.blank? || suggestion == '0' || suggestion == 'New Prescription')
        @order = DrugOrder.find(suggestion)
        DrugOrder.clone_order(@encounter, @patient, @diagnosis, @order)
      else
        
        @formulation = (params[:formulation] || '').upcase
        @drug = Drug.find_by_name(@formulation) rescue nil
        unless @drug
          flash[:notice] = "No matching drugs found for formulation #{params[:formulation]}"
          render :new
          return
        end  
        start_date = session_date
        auto_expire_date = session_date.to_date + params[:duration].to_i.days
        prn = params[:prn].to_i
        if params[:type_of_prescription] == "variable"
          DrugOrder.write_order(@encounter, @patient, @diagnosis, @drug, start_date, auto_expire_date, [params[:morning_dose], params[:afternoon_dose], params[:evening_dose], params[:night_dose]], 'VARIABLE', prn)
        else
          DrugOrder.write_order(@encounter, @patient, @diagnosis, @drug, start_date, auto_expire_date, params[:dose_strength], params[:frequency], prn)
        end  
      end  
    end

    unless params[:location]
      redirect_to (params[:auto] == '1' ? "/prescriptions/auto?patient_id=#{@patient.id}" : "/patients/treatment_dashboard/#{@patient.id}")
    else
      render :text => 'import success' and return
    end
    
  end
  
  def auto
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    # Find the next diagnosis that doesn't have a corresponding order
    @diagnoses = current_diagnoses(@patient.person.id)
    @prescriptions = @patient.orders.current.prescriptions.all.map(&:obs_id).uniq
    @diagnoses = @diagnoses.reject {|diag| @prescriptions.include?(diag.obs_id) }
    if @diagnoses.empty?
      redirect_to "/prescriptions/new?patient_id=#{@patient.id}"
    else
      redirect_to "/prescriptions/new?patient_id=#{@patient.id}&diagnosis=#{@diagnoses.first.obs_id}&auto=#{@diagnoses.length == 1 ? 0 : 1}"
    end  
  end
  
  # Look up the set of matching generic drugs based on the concepts. We 
  # limit the list to only the list of drugs that are actually in the 
  # drug list so we don't pick something we don't have.
  def generics
    search_string = (params[:search_string] || '').upcase
    filter_list = params[:filter_list].split(/, */) rescue []    
    @drug_concepts = ConceptName.find(:all, 
      :select => "concept_name.name", 
      :joins => "INNER JOIN drug ON drug.concept_id = concept_name.concept_id AND drug.retired = 0", 
      :conditions => ["concept_name.name LIKE ?", '%' + search_string + '%'],:group => 'drug.concept_id')
    render :text => "<li>" + @drug_concepts.map{|drug_concept| drug_concept.name }.uniq.join("</li><li>") + "</li>"
  end
  
  # Look up all of the matching drugs for the given generic drugs
  def formulations
    @generic = (params[:generic] || '')
    @concept_ids = ConceptName.find_all_by_name(@generic).map{|c| c.concept_id}
    render :text => "" and return if @concept_ids.blank?
    search_string = (params[:search_string] || '').upcase
    @drugs = Drug.find(:all, 
      :select => "name", 
      :conditions => ["concept_id IN (?) AND name LIKE ?", @concept_ids, '%' + search_string + '%'])
    render :text => "<li>" + @drugs.map{|drug| drug.name }.join("</li><li>") + "</li>"
  end
  
  # Look up likely durations for the drug
  def durations
    @formulation = (params[:formulation] || '').upcase
    drug = Drug.find_by_name(@formulation) rescue nil
    render :text => "No matching drugs found for #{params[:formulation]}" and return unless drug

    # Grab the 10 most popular durations for this drug
    amounts = []
    orders = DrugOrder.find(:all, 
      :select => 'DATEDIFF(orders.auto_expire_date, orders.start_date) as duration_days',
      :joins => 'LEFT JOIN orders ON orders.order_id = drug_order.order_id AND orders.voided = 0',
      :limit => 10, 
      :group => 'drug_inventory_id, DATEDIFF(orders.auto_expire_date, orders.start_date)', 
      :order => 'count(*)', 
      :conditions => {:drug_inventory_id => drug.id})
      
    orders.each {|order|
      amounts << "#{order.duration_days.to_f}" unless order.duration_days.blank?
    }  
    amounts = amounts.flatten.compact.uniq
    render :text => "<li>" + amounts.join("</li><li>") + "</li>"
  end

  # Look up likely dose_strength for the drug
  def dosages
    @formulation = (params[:formulation] || '')
    drug = Drug.find_by_name(@formulation) rescue nil
    render :text => "No matching drugs found for #{params[:formulation]}" and return unless drug

    @frequency = (params[:frequency] || '')

    # Grab the 10 most popular dosages for this drug
    amounts = []
    amounts << "#{drug.dose_strength}" if drug.dose_strength 
    orders = DrugOrder.find(:all, 
      :limit => 10, 
      :group => 'drug_inventory_id, dose', 
      :order => 'count(*)', 
      :conditions => {:drug_inventory_id => drug.id, :frequency => @frequency})
    orders.each {|order|
      amounts << "#{order.dose}"
    }  
    amounts = amounts.flatten.compact.uniq
    render :text => "<li>" + amounts.join("</li><li>") + "</li>"
  end

  # Look up the units for the first substance in the drug, ideally we should re-activate the units on drug for aggregate units
  def units
    @formulation = (params[:formulation] || '').upcase
    drug = Drug.find_by_name(@formulation) rescue nil
    render :text => "per dose" and return unless drug && !drug.units.blank?
    render :text => drug.units
  end
  
  def suggested
    @diagnosis = Observation.find(params[:diagnosis]) rescue nil
    @options = []
    render :layout => false and return unless @diagnosis && @diagnosis.value_coded
    @orders = DrugOrder.find_common_orders(@diagnosis.value_coded)
    @options = @orders.map{|o| [o.order_id, o.script] } + @options
    render :layout => false
  end
  
  # Look up all of the matching drugs for the given drug name
  def name
    search_string = (params[:search_string] || '').upcase
    @drugs = Drug.find(:all, 
      :select => "name", 
      :conditions => ["name LIKE ?", '%' + search_string + '%'])
    render :text => "<li>" + @drugs.map{|drug| drug.name }.join("</li><li>") + "</li>"
  end

  #data cleaning :- moved from patient.rb
  def current_diagnoses(patient_id)
    patient = Patient.find(patient_id)
    patient.encounters.current.all(:include => [:observations]).map{|encounter|
      encounter.observations.all(
        :conditions => ["obs.concept_id = ? OR obs.concept_id = ?",
          ConceptName.find_by_name("DIAGNOSIS").concept_id,
          ConceptName.find_by_name("DIAGNOSIS, NON-CODED").concept_id])
    }.flatten.compact
  end

  def load_frequencies_and_dosages
    drugs = MedicationService.dosages(params[:concept_id])
    render :text => drugs.to_json
  end
  
  def generic_advanced_prescription
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @generics = MedicationService.generic
    @frequencies = MedicationService.frequencies
    @diagnosis = @patient.current_diagnoses["DIAGNOSIS"] rescue []
    render :layout => 'application'
  end
  
  def create_advanced_prescription
    # raise params.to_yaml

    encounter = Encounter.new(params[:encounter])
    encounter.encounter_datetime = session[:datetime] rescue DateTime.now()
    encounter.save

    (params[:prescriptions] || []).each{|prescription|      
      @patient    = Patient.find(prescription[:patient_id] || session[:patient_id]) rescue nil
      @encounter  = encounter

      diagnosis_name = prescription[:value_coded_or_text]

      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        prescription["value_#{value_name}"] unless prescription["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      prescription.delete(:value_text) unless prescription[:value_coded_or_text].blank?

      prescription[:encounter_id]  = @encounter.encounter_id
      prescription[:obs_datetime]  = @encounter.encounter_datetime || (session[:datetime] ||  Time.now())
      prescription[:person_id]     = @encounter.patient_id

      diagnosis_observation = Observation.create("encounter_id" => prescription[:encounter_id],
        "concept_name" => "DIAGNOSIS",
        "obs_datetime" => prescription[:obs_datetime],
        "person_id" => prescription[:person_id],
        "value_coded_or_text" => diagnosis_name)

      prescription[:diagnosis] = diagnosis_observation.id

      @diagnosis = Observation.find(prescription[:diagnosis]) rescue nil

      prescription[:dosage] =  "" unless !prescription[:dosage].nil?

      prescription[:formulation] = [prescription[:drug],
                                    prescription[:dosage],
                                    prescription[:frequency],
                                    prescription[:strength],
                                    prescription[:units]]

      drug_info = advanced_drug_details(prescription[:formulation]).first

      prescription[:formulation]    = drug_info[:drug_formulation] rescue nil
      prescription[:frequency]      = drug_info[:drug_frequency] rescue nil
      prescription[:prn]            = drug_info[:drug_prn] rescue nil
      prescription[:dosage]         = drug_info[:drug_strength] rescue nil

      @formulation = (prescription[:formulation] || '').upcase

      @drug = Drug.find_by_name(@formulation) rescue nil

      unless @drug
        flash[:notice] = "No matching drugs found for formulation #{prescription[:formulation]}"
        @patient = Patient.find(prescription[:patient_id] || session[:patient_id]) rescue nil
        @generics = Drug.generic
        @frequencies = Drug.frequencies
        @diagnosis = @patient.current_diagnoses["DIAGNOSIS"] rescue []
        
        render :treatment
        return
      end

      start_date = session[:datetime] ||  Time.now
      auto_expire_date = (session[:datetime] ||  Time.now) + prescription[:duration].to_i.days
      
      DrugOrder.write_order(@encounter, @patient, @diagnosis, @drug, start_date, 
        auto_expire_date, prescription[:dosage], prescription[:frequency], 0 , nil)
      
    }

    if(@patient)
      redirect_to "/patients/treatment_dashboard/#{@patient.id}" and return
    else
      redirect_to "/patients/treatment_dashboard/#{params[:patient_id]}" and return
    end

  end
 
  def advanced_drug_details(drug_info)
    
    insulin = false
    if (drug_info[0].downcase.include? "insulin") && ((drug_info[0].downcase.include? "lente") ||
          (drug_info[0].downcase.include? "soluble")) || ((drug_info[0].downcase.include? "glibenclamide") && (drug_info[1] == ""))

      if(drug_info[0].downcase == "insulin, lente")     # due to error noticed when searching for drugs
        drug_info[0] = "LENTE INSULIN"
      end

      if(drug_info[0].downcase == "insulin, soluble")     # due to error noticed when searching for drugs
        drug_info[0] = "SOLUBLE INSULIN"
      end

      name = "%"+drug_info[0]+"%"
      insulin = true

    else

      # do not remove the '(' in the following string
      name = "%"+drug_info[0]+"%"+drug_info[1]+"%"

    end

    drug_details = Array.new

    concept_name_id = ConceptName.find_by_name("DRUG FREQUENCY CODED").concept_id

    drugs = Drug.find(:all, :select => "concept.concept_id AS concept_id, concept_name.name AS name,
        drug.dose_strength AS strength, drug.name AS formulation",
      :joins => "INNER JOIN concept       ON drug.concept_id = concept.concept_id
               INNER JOIN concept_name  ON concept_name.concept_id = concept.concept_id",
      :conditions => ["drug.name LIKE ? OR (concept_name.name LIKE ? AND COALESCE(drug.dose_strength, 0) = ? " +
          "AND COALESCE(drug.units, '') = ?)", name, "%" + drug_info[0] + "%", drug_info[3], drug_info[4]],
      :group => "concept.concept_id, drug.name, drug.dose_strength")

    # raise drugs.to_yaml
    
    unless(insulin)

      drug_frequency = drug_info[2].upcase rescue nil

      preferred_concept_name_id = Concept.find_by_name(drug_frequency).concept_id
      preferred_dmht_tag_id = ConceptNameTag.find_by_tag("preferred_dmht").concept_name_tag_id

      drug_frequency = ConceptName.find(:first, :select => "concept_name.name",
        :joins => "INNER JOIN concept_answer ON concept_name.concept_id = concept_answer.answer_concept
                                INNER JOIN concept_name_tag_map cnmp
                                  ON  cnmp.concept_name_id = concept_name.concept_name_id",
        :conditions => ["concept_answer.concept_id = ? AND concept_name.concept_id = ? AND voided = 0
                                  AND cnmp.concept_name_tag_id = ?", concept_name_id, preferred_concept_name_id, preferred_dmht_tag_id])

      drugs.each do |drug|

        drug_details += [:drug_concept_id => drug.concept_id,
          :drug_name => drug.name, :drug_strength => drug.strength,
          :drug_formulation => drug.formulation, :drug_prn => 0, :drug_frequency => drug_frequency.name]

      end

    else

      drugs.each do |drug|

        drug_details += [:drug_concept_id => drug.concept_id,
          :drug_name => drug.name, :drug_strength => drug.strength,
          :drug_formulation => drug.formulation, :drug_prn => 0, :drug_frequency => ""]

      end rescue []

    end

    drug_details

  end
 
  def advanced_prescription
    @patient = Patient.find(params[:patient_id] || params[:id] || session[:patient_id]) rescue nil

    @orders = MedicationService.current_orders(@patient) rescue []

    diabetes_id = Concept.find_by_name("DIABETES MEDICATION").id

    @patient_diabetes_treatements     = []
    @patient_hypertension_treatements = []

    DiabetesService.treatments(@patient).map{|treatement|


      if (treatement.diagnosis_id.to_i == diabetes_id && DiabetesService.treatments(@patient).first.start_date.to_date == treatement.start_date.to_date)
        @patient_diabetes_treatements << treatement
      elsif(DiabetesService.treatments(@patient).first.start_date.to_date == treatement.start_date.to_date)
        @patient_hypertension_treatements << treatement
      end
    }
    #raise @patient_diabetes_treatements.to_yaml
    redirect_to "/prescriptions/advanced_new?patient_id=#{params[:patient_id] || session[:patient_id]}" and return if @patient_diabetes_treatements.blank?   #@orders.blank?
    render :template => 'prescriptions/advanced_prescription', :layout => 'complications'
  end
  
  def advanced_new
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil

    diabetes_id = Concept.find_by_name("DIABETES MEDICATION").id

    @patient_diabetes_treatements     = []
    @patient_hypertension_treatements = []

    DiabetesService.treatments(@patient).map{|treatement|

      if (treatement.diagnosis_id.to_i == diabetes_id)
        @patient_diabetes_treatements << treatement
      else
        @patient_hypertension_treatements << treatement
      end
    }

  end
  
  def advanced_create
    (params[:prescriptions] || []).each{|prescription|
      @suggestion = prescription[:suggestion]
      @patient    = Patient.find(prescription[:patient_id] || session[:patient_id]) rescue nil
      @encounter  = MedicationService.current_treatment_encounter(@patient)

      diagnosis_name = prescription[:diagnosis]

      diabetes_clinic = false

      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        prescription["value_#{value_name}"] unless prescription["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      prescription.delete(:value_text) unless prescription[:value_coded_or_text].blank?

      prescription[:encounter_id]  = @encounter.encounter_id
      prescription[:obs_datetime]  = @encounter.encounter_datetime ||= Time.now()
      prescription[:person_id]     = @encounter.patient_id

      diagnosis_observation = Observation.create("encounter_id" => prescription[:encounter_id],
        "concept_name" => prescription[:concept_name],
        "obs_datetime" => prescription[:obs_datetime],
        "person_id" => prescription[:person_id],
        "value_coded_or_text" => prescription[:value_coded_or_text])

      prescription[:diagnosis]    = diagnosis_observation.id

      @diagnosis = Observation.find(prescription[:diagnosis]) rescue nil
      diabetes_clinic = true if (['DIABETES MEDICATION','HYPERTENSION','PERIPHERAL NEUROPATHY'].include?(diagnosis_name))

      if diabetes_clinic
        prescription[:drug_strength] =  "" unless !prescription[:drug_strength].nil?

        prescription[:formulation] = [prescription[:generic], prescription[:drug_strength], prescription[:frequency]]

        drug_info = DiabetesService.drug_details(prescription[:formulation], diagnosis_name).first

        # raise drug_info.inspect

        prescription[:formulation]    = drug_info[:drug_formulation]
        prescription[:frequency]      = drug_info[:drug_frequency]
        prescription[:prn]            = drug_info[:drug_prn]
        prescription[:dose_strength]  = drug_info[:drug_strength]
      end

      unless (@suggestion.blank? || @suggestion == '0')
        @order = DrugOrder.find(@suggestion)
        DrugOrder.clone_order(@encounter, @patient, @diagnosis, @order)
      else
        @formulation = (prescription[:formulation] || '').upcase

        @drug = Drug.find_by_name(@formulation) rescue nil

        unless @drug
          flash[:notice] = "No matching drugs found for formulation #{prescription[:formulation]}"
          render :new
          return
        end
        start_date = Time.now
        auto_expire_date = Time.now + prescription[:duration].to_i.days
        prn = prescription[:prn]
        if prescription[:type_of_prescription] == "variable"
          DrugOrder.write_order(@encounter, @patient, @diagnosis, @drug, start_date, auto_expire_date, prescription[:morning_dose], 'MORNING', prn) unless prescription[:morning_dose] == "Unknown" || prescription[:morning_dose].to_f == 0
          DrugOrder.write_order(@encounter, @patient, @diagnosis, @drug, start_date, auto_expire_date, prescription[:afternoon_dose], 'AFTERNOON', prn) unless prescription[:afternoon_dose] == "Unknown" || prescription[:afternoon_dose].to_f == 0
          DrugOrder.write_order(@encounter, @patient, @diagnosis, @drug, start_date, auto_expire_date, prescription[:evening_dose], 'EVENING', prn) unless prescription[:evening_dose] == "Unknown" || prescription[:evening_dose].to_f == 0
          DrugOrder.write_order(@encounter, @patient, @diagnosis, @drug, start_date, auto_expire_date, prescription[:night_dose], 'NIGHT', prn)  unless prescription[:night_dose] == "Unknown" || prescription[:night_dose].to_f == 0
        else
          DrugOrder.write_order(@encounter, @patient, @diagnosis, @drug, start_date, auto_expire_date, prescription[:dose_strength], prescription[:frequency], prn)
        end
      end

    }

    if(@patient)
      redirect_to "/prescriptions/advanced_prescription?patient_id=#{@patient.id}"
    else
      redirect_to "/prescriptions/advanced_prescription?patient_id=#{params[:patient_id]}"
    end
    
  end
end
