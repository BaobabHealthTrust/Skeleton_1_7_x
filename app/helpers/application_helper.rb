# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def link_to_onmousedown(name, options = {}, html_options = nil, *parameters_for_method_reference)
    html_options = Hash.new if html_options.nil?
    html_options["onMouseDown"]="this.style.backgroundColor='lightblue';document.location=this.href"
    html_options["onClick"]="return false" #if we don't do this we get double clicks
    link = link_to(name, options, html_options, *parameters_for_method_reference)
  end

  def img_button_submit_to(url, image, options = {}, params = {})
    content = ""
    content << "<form method='post' action='#{url}'><input type='image' src='#{image}'/>"
    params.each {|n,v| content << "<input type='hidden' name='#{n}' value='#{v}'/>" }
    content << "</form>"
    content
  end
  
  def img_button_submit_to_with_confirm(url, image, options = {}, params = {})
    content = ""
    content << "<form " + ((options[:form_id])?("id=#{options[:form_id]}"):"id='frm_general'") + " method='post' action='#{url}'><input type='image' src='#{image}' " +
      ((options[:confirm])?("onclick=\"return confirmRecordDeletion('" +
      options[:confirm] + "', '" + ((options[:form_id])?("#{options[:form_id]}"):"frm_general") + "')\""):"") + "/>"

    params.each {|n,v| content << "<input type='hidden' name='#{n}' value='#{v}'/>" }
    content << "</form>"
    content
  end
  
  def fancy_or_high_contrast_touch
    fancy = get_global_property_value("interface") == "fancy" rescue false
    fancy ? "touch-fancy.css" : "touch.css"
  end
  
  def show_intro_text
    get_global_property_value("show_intro_text").to_s == "true" rescue false
  end
  
  def ask_home_village
    get_global_property_value("demographics.home_village").to_s == "true" rescue false
  end

  def site_prefix
    site_prefix = get_global_property_value("site_prefix") rescue false
    return site_prefix
  end

  def ask_mothers_surname
    get_global_property_value("demographics.mothers_surname").to_s == "true" rescue false
  end
  
  def ask_middle_name
    get_global_property_value("demographics.middle_name").to_s == "true" rescue false
  end

  def ask_visit_home_for_TB_therapy
    get_global_property_value("demographics.visit_home_for_treatment").to_s == "true" rescue false
  end
  
  def ask_sms_for_TB_therapy
    get_global_property_value("demographics.sms_for_TB_therapy").to_s == "true" rescue false
  end

  def ask_ground_phone
    get_global_property_value("demographics.ground_phone").to_s == "true" rescue false
  end

  def ask_blood_pressure
    get_global_property_value("vitals.blood_pressure").to_s == "true" rescue false
  end

  def ask_temperature
    get_global_property_value("vitals.temperature").to_s == "true" rescue false
  end  

  def ask_standard_art_side_effects
    get_global_property_value("art_visit.standard_art_side_effects").to_s == "true" rescue false
  end  

  def show_lab_results
    get_global_property_value('show.lab.results').to_s == "true" rescue false
  end
  
  def use_filing_number
    get_global_property_value('use.filing.number').to_s == "true" rescue false
  end

  def use_user_selected_activities
    get_global_property_value('use.user.selected.activities').to_s == "true" rescue false
  end

  def use_extended_staging_questions
    get_global_property_value('use.extended.staging.questions').to_s == "true" rescue false
  end
  
  def prefix
    get_global_property_value("dc.number.prefix") rescue ""
  end
  
  def advanced_prescription_interface
    get_global_property_value("advanced.prescription.interface")  
  end

	def get_global_property_value(global_property)
		property_value = Settings[global_property] 
		if property_value.nil?
			property_value = GlobalProperty.find(:first, :conditions => {:property => "#{global_property}"}
													).property_value rescue nil
		end
		return property_value
	end

  def month_name_options(selected_months = [])
    i=0
    options_array = [[]] +Date::ABBR_MONTHNAMES[1..-1].collect{|month|[month,i+=1]} + [["Unknown","Unknown"]]
    options_for_select(options_array, selected_months)  
  end
  
  def age_limit
    Time.now.year - 1890
  end

  def version
    #"Bart Version: #{BART_VERSION}#{' ' + BART_SETTINGS['installation'] if BART_SETTINGS}, #{File.ctime(File.join(RAILS_ROOT, 'config', 'environment.rb')).strftime('%d-%b-%Y')}"
    style = "style='background-color:red;'" unless session[:datetime].blank?
    "Bart Version: #{BART_VERSION} - <span #{style}>#{(session[:datetime].to_date rescue Date.today).strftime('%A, %d-%b-%Y')}</span>"
  end
  
  def welcome_message
    "Muli bwanji, enter your user information or scan your id card. <span style='font-size:0.6em;float:right'>(#{version})</span>"  
  end
  
  def show_identifiers(location_id, patient)
    content = ""
    idents = get_global_property_value("dashboard.identifiers")
    json = JSON.parse(idents)
    names = json[location_id.to_s] rescue []
    names.each do |name|
      ident_type = PatientIdentifierType.find_by_name(name)
      next if ident_type.blank?
      ident = patient.patient_identifiers.find_by_identifier_type(ident_type.id)
      next if ident.blank?
      content << "<span class='title'>#{name}:</span> #{ident.identifier}"       
    end
    content
  end
  
  def patient_image(patient) 
    @patient.person.gender == 'M' ? "<img src='/images/male.gif' alt='Male' height='30px' style='margin-bottom:-4px;'>" : "<img src='/images/female.gif' alt='Female' height='30px' style='margin-bottom:-4px;'>"
  end

  # include (patient, :names => true) to list registered guardians
  def relationship_options(patient, options={})
    options_array = []
    if options[:names] # show names of guardians as options
      rels = patient.relationships.all
      # filter out voided relationship target
      rels.each do |rel|
        unless rel.relation.blank?
          options_array << [rel.relation.name + " (#{rel.type.b_is_to_a})",
                            rel.relation.name]
        end
      end
      options_array << ['None', 'None']
    else
      options_array << ['Yes', 'Yes']
      options_array << ['No', 'No']
    end
    options_array << ['Unknown', 'Unknown']
    options_for_select(options_array)  
  end
  
  def program_enrollment_options(patient, filter_program_name=nil)
    progs = @patient.patient_programs.all
    progs.reject!{|prog| prog.program.name != filter_program_name} unless filter_program_name.blank?
    options_array = progs.map{|prog| [prog.program.name + " (started #{prog.date_enrolled.strftime('%d/%b/%Y')} at #{prog.location.name})", prog.id]}
    options_for_select(options_array)  
  end
  
  def concept_set_options(concept_name)
    concept_id = ConceptName.find(:first,:joins =>"INNER JOIN concept USING (concept_id)",
                                  :conditions =>["voided = 0 AND concept.retired = 0 AND name = ?",concept_name]).concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }
    options_for_select(options)
  end


  def selected_concept_set_options(concept_name, exclude_concept_name)
    concept_id = ConceptName.find(:first,:joins =>"INNER JOIN concept USING (concept_id)",
                                  :conditions =>["voided = 0 AND concept.retired = 0 AND name = ?",concept_name]).concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

    exclude_concept_id = ConceptName.find(:first,:joins =>"INNER JOIN concept USING (concept_id)",
                                  :conditions =>["voided = 0 AND concept.retired = 0 AND name = ?", exclude_concept_name]).concept_id
    exclude_set = ConceptSet.find_all_by_concept_set(exclude_concept_id, :order => 'sort_weight')
    exclude_options = exclude_set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

    options_for_select(options - exclude_options)
  end
  
  def concept_set(concept_name)
    concept_id = ConceptName.find(:first,:joins =>"INNER JOIN concept USING (concept_id)",
                                  :conditions =>["voided = 0 AND concept.retired = 0 AND name = ?",concept_name]).concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname] }
    return options
  end

  def development_environment?
    ENV['RAILS_ENV'] == 'development'
  end

  def generic_locations
    field_name = "name"

    Location.find_by_sql("SELECT *
            FROM location
          WHERE location_id IN (SELECT location_id
                         FROM location_tag_map
                          WHERE location_tag_id = (SELECT location_tag_id
                                 FROM location_tag
                                 WHERE name = 'Workstation Location'))
             ORDER BY name ASC").collect{|name| name.send(field_name)} rescue []
  end
  
  def concept_sets(concept_name)
    concept_id = ConceptName.find(:first,:joins =>"INNER JOIN concept USING (concept_id)",
                                  :conditions =>["retired = 0 AND name = ?",concept_name]).concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    set.map{|item|next if item.concept.blank? ; item.concept.fullname }
  end

  def convert_time(duration)
		if(!duration.blank?)
			if(duration.to_i < 7)
				(duration.to_i > 0)?(( duration.to_i > 1)? "#{duration} days" :"1 day"): "<i>(New)</i>"
			elsif(duration.to_i < 30)
				week = (duration.to_i)/7
				week > 1? "#{week} weeks" : "1 week"
			elsif(duration.to_i < 367)
				month = (duration.to_i)/30
				month > 1? "#{month} months" : "1 month"
			else
				year = (duration.to_i)/365
				year > 1? "#{year} years" : "1 year"
			end
		end
	end
	
	def qwerty_or_abc_keyboard
		abc = UserProperty.find_by_property_and_user_id('keyboard',session[:user_id]).property_value == 'abc' rescue false
		abc ? "abc" : "qwerty"
	end
	
end
