class Property

  def self.clinic_appointment_limit(end_date = nil)
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
