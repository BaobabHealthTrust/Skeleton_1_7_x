class GenericPrescriptionsController < ApplicationController
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
    @patient_diagnoses = PatientService.current_diagnoses(@patient.person.id)
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
      user_person_id = User.find_by_user_id(current_user.user_id).person_id
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
    @diagnoses = PatientService.current_diagnoses(@patient.person.id)
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

	def generic_advanced_prescription
		@patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
		@generics = MedicationService.generic
		@frequencies = MedicationService.fully_specified_frequencies	
		@formulations = {}
		@generics.each { | generic |
			drugs = Drug.find(:all,	:conditions => ["concept_id = ?", generic[1]])
			drug_formulations = {}			
			drugs.each { | drug |
				drug_formulations[drug.name] = [drug.dose_strength, drug.units]
			}
			@formulations[generic[1]] = drug_formulations			
		}

		@diagnosis = @patient.current_diagnoses["DIAGNOSIS"] rescue []
		render :layout => 'application'
	end
  
  
	def create_advanced_prescription
		@patient    = Patient.find(params[:encounter][:patient_id]  || session[:patient_id]) rescue nil
		encounter  = MedicationService.current_treatment_encounter(@patient)
    
		if params[:prescription].blank?
			next if params[:formulation].blank?
          	formulation = (params[:formulation] || '').upcase
			drug = Drug.find_by_name(formulation) rescue nil
			unless drug
				flash[:notice] = "No matching drugs found for formulation #{params[:formulation]}"
				render :new
				return
			end
			start_date = session[:datetime].to_date rescue Time.now
			auto_expire_date = session_date.to_date + params[:duration].to_i.days
			prn = params[:prn].to_i

			if prescription[:type_of_prescription] == "variable"
				DrugOrder.write_order(encounter, @patient, nil, drug, start_date, auto_expire_date, [prescription[:morning_dose], 
					prescription[:afternoon_dose], prescription[:evening_dose], prescription[:night_dose]], 
					prescription[:type_of_prescription], prn)
			else
				DrugOrder.write_order(encounter, @patient, nil, drug, start_date, auto_expire_date, prescription[:dose_strength], 
					prescription[:frequency], prn)
			end
		else
			(params[:prescription] || []).each{ | prescription |      
				prescription[:encounter_id]  = encounter.encounter_id
				prescription[:obs_datetime]  = encounter.encounter_datetime || (session[:datetime] ||  Time.now())
				prescription[:person_id]     = encounter.patient_id

				formulation = (prescription[:formulation] || '').upcase

				drug = Drug.find_by_name(formulation) rescue nil

				unless drug
					flash[:notice] = "No matching drugs found for formulation #{prescription[:formulation]}"
					render :new
					return
				end

				start_date = session[:datetime].to_date rescue nil
        start_date = Time.now() if start_date.blank?

				auto_expire_date = start_date + prescription[:duration].to_i.days
				prn = prescription[:prn]


				if prescription[:type_of_prescription] == "variable"
					DrugOrder.write_order(encounter, @patient, nil, drug, start_date, auto_expire_date, [prescription[:morning_dose], 
						prescription[:afternoon_dose], prescription[:evening_dose], prescription[:night_dose]], 
						prescription[:type_of_prescription], prn)
				else
					DrugOrder.write_order(encounter, @patient, nil, drug, start_date, auto_expire_date, prescription[:dose_strength], 
						prescription[:frequency], prn)
				end

			}
		end

		if(@patient)
			redirect_to "/patients/treatment_dashboard/#{@patient.id}" and return
		else
			redirect_to "/patients/treatment_dashboard/#{params[:patient_id]}" and return
		end

	end
end
