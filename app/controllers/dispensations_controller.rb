class DispensationsController < ApplicationController
  def new
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil

    #@prescriptions = @patient.orders.current.prescriptions.all
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
                     :joins => "INNER JOIN encounter e USING (encounter_id)", 
                     :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
                     type.id,@patient.id,session_date]) 
    @options = @prescriptions.map{|presc| [presc.drug_order.drug.name, presc.drug_order.drug_inventory_id]}
  end

  def create
    if (params[:identifier])
      params[:drug_id] = params[:identifier].match(/^\d+/).to_s
      params[:quantity] = params[:identifier].match(/\d+$/).to_s
    end
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    unless params[:location]
      session_date = session[:datetime] || Time.now()
    else
      session_date = params[:encounter_datetime] #Use date_created passed during import
    end

    @drug = Drug.find(params[:drug_id]) rescue nil
    #TODO look for another place to put this block of code
    if @drug.blank? or params[:quantity].blank?
      flash[:error] = "There is no drug with barcode: #{params[:identifier]}"
      redirect_to "/patients/treatment_dashboard/#{@patient.patient_id}" and return
    end if (params[:identifier])

    # set current location via params if given
    Location.current_location = Location.find(params[:location]) if params[:location]

    if params[:filter] and !params[:filter][:provider].blank?
      user_person_id = User.find_by_username(params[:filter][:provider]).person_id
    elsif params[:location]
      user_person_id = params[:provider_id]
    else
      user_person_id = User.find_by_user_id(session[:user_id]).person_id
    end

    @encounter = current_dispensation_encounter(@patient, session_date, user_person_id)

    @order = PatientService.current_treatment_encounter( @patient, session_date, user_person_id).drug_orders.find(:first,:conditions => ['drug_order.drug_inventory_id = ?', 
             params[:drug_id]]).order rescue []

    # Do we have an order for the specified drug?
    if @order.blank?
      if params[:location]
        @order_id = ''
        @drug_value = params[:drug_id]
      else
        flash[:error] = "There is no prescription for #{@drug.name}"
        redirect_to "/patients/treatment_dashboard/#{@patient.patient_id}" and return
      end
    else
      @order_id = @order.order_id
      @drug_value = @order.drug_order.drug_inventory_id
    end
    #assign the order_id and  drug_inventory_id
    # Try to dispense the drug
      
    obs = Observation.new(
      :concept_name => "AMOUNT DISPENSED",
      :order_id => @order_id,
      :person_id => @patient.person.person_id,
      :encounter_id => @encounter.id,
      :value_drug => @drug_value,
      :value_numeric => params[:quantity],
      :obs_datetime => session_date || Time.now())
    if obs.save
      @patient.patient_programs.find_last_by_program_id(Program.find_by_name("HIV PROGRAM")).transition(
               :state => "On antiretrovirals",:start_date => session_date || Time.now()) if MedicationService.arv(@drug) rescue nil

      @patient.patient_programs.find_last_by_program_id(Program.find_by_name("DIABETES PROGRAM")).transition(
               :state => "On treatment",:start_date => session_date || Time.now()) if MedicationService.diabetes_medication(@drug) rescue nil
               
			@tb_programs = @patient.patient_programs.in_uncompleted_programs(['TB PROGRAM', 'MDR-TB PROGRAM'])

      if !@tb_programs.blank?
        @patient.patient_programs.find_last_by_program_id(Program.find_by_name("TB PROGRAM")).transition(
               :state => "Currently in treatment",:start_date => session_date || Time.now()) if   MedicationService.tb_medication(@drug)
      end

      unless @order.blank?
        @order.drug_order.total_drug_supply(@patient, @encounter,session_date.to_date)

        #checks if the prescription is satisfied
        complete = dispension_complete(@patient, @encounter, PatientService.current_treatment_encounter(@patient, session_date, user_person_id))
        if complete
          unless params[:location]
            start_date , end_date = DrugOrder.prescription_dates(@patient,session_date.to_date)
            redirect_to :controller => 'encounters',:action => 'new',
              :start_date => start_date,
              :patient_id => @patient.id,:id =>"show",:encounter_type => "appointment" ,
              :end_date => end_date
          else
            render :text => 'complete' and return
          end
        else
          unless params[:location]
            redirect_to "/patients/treatment_dashboard?id=#{@patient.patient_id}&dispensed_order_id=#{@order_id}"
          else
            render :text => 'complete' and return
          end
        end
      else
        render :text => 'complete' and return
      end
    else
      flash[:error] = "Could not dispense the drug for the prescription"
      redirect_to "/patients/treatment_dashboard/#{@patient.patient_id}"
    end
  end  
  
  def quantities 
    drug = Drug.find(params[:formulation])
    # Most common quantity should be for the generic, not the specific
    # But for now, the value_drug shortcut is significant enough that we 
    # Should just use it. Also, we are using the AMOUNT DISPENSED obs
    # and not the drug_order.quantity because the quantity contains number
    # of pills brought to clinic and we should assume that the AMOUNT DISPENSED
    # observations more accurately represent pack sizes
    amounts = []
    Observation.question("AMOUNT DISPENSED").all(
      :conditions => {:value_drug => drug.drug_id},
      :group => 'value_drug, value_numeric',
      :order => 'count(*)',
      :limit => '10').each do |obs|
      amounts << "#{obs.value_numeric.to_f}" unless obs.value_numeric.blank?
    end
    amounts = amounts.flatten.compact.uniq
    render :text => "<li>" + amounts.join("</li><li>") + "</li>"
  end

  def current_dispensation_encounter(patient, date = Time.now(), provider = user_person_id)
    type = EncounterType.find_by_name("DISPENSING")
    encounter = patient.encounters.find(:first,:conditions =>["DATE(encounter_datetime) = ? AND encounter_type = ?",date.to_date,type.id])
    encounter ||= patient.encounters.create(:encounter_type => type.id,:encounter_datetime => date, :provider_id => provider)
  end

  def set_received_regimen(patient, encounter,prescription)
    dispense_finish = true ; dispensed_drugs_inventory_ids = []

    prescription.orders.each do | order |
      next if not MedicationService.arv(order.drug_order.drug)
      dispensed_drugs_inventory_ids << order.drug_order.drug.id
      if (order.drug_order.amount_needed > 0)
        dispense_finish = false
      end
    end

    return unless dispense_finish
    return if dispensed_drugs_inventory_ids.blank?

    regimen_id = ActiveRecord::Base.connection.select_all <<EOF
SELECT r.concept_id ,
(SELECT COUNT(t3.regimen_id) FROM regimen_drug_order t3
WHERE t3.regimen_id = t.regimen_id GROUP BY t3.regimen_id) as c
FROM regimen_drug_order t, regimen r
WHERE t.drug_inventory_id IN (#{dispensed_drugs_inventory_ids.join(',')})
AND r.regimen_id = t.regimen_id
GROUP BY r.concept_id
HAVING c = #{dispensed_drugs_inventory_ids.length}
EOF

    regimen_prescribed = regimen_id.first['concept_id'].to_i rescue ConceptName.find_by_name('UNKNOWN ANTIRETROVIRAL DRUG').concept_id

    if (Observation.find(:first,:conditions => ["person_id = ? AND encounter_id = ? AND concept_id = ?",
            patient.id,encounter.id,ConceptName.find_by_name('ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT').concept_id])).blank?
      regimen_value_text = Concept.find(regimen_prescribed).shortname rescue nil
      if regimen_value_text.blank?
        regimen_value_text = ConceptName.find_by_concept_id(regimen_prescribed).name rescue nil
      end
      return if regimen_value_text.blank?
      obs = Observation.new(
        :concept_name => "ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT",
        :person_id => patient.id,
        :encounter_id => encounter.id,
        :value_text => regimen_value_text,
        :value_coded => regimen_prescribed,
        :obs_datetime => encounter.encounter_datetime)
      obs.save
      return obs.value_text
    end
  end

  private

  def dispension_complete(patient,encounter,prescription)
    complete = false
    prescription.drug_orders.each do | drug_order |
      complete = (drug_order.amount_needed <= 0)
      complete = false and break if not complete
    end

    if complete
      dispension_completed = set_received_regimen(patient, encounter,prescription)
    end
    return DrugOrder.all_orders_complete(patient,encounter.encounter_datetime.to_date)
  end

end
