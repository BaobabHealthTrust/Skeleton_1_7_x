
LOG_FILE_UNVOIDED = RAILS_ROOT + '/log/unvoided_encounters.log'
LOG_FILE_VOIDED = RAILS_ROOT + '/log/voided_encounters.log'
LOG_FILE_MISSING = RAILS_ROOT + '/log/missing_encounters.log'
LOG_MONITOR = RAILS_ROOT + '/log/monitor.log'

START_DATE = '01-01-2011'
END_DATE = '31-12-2011'

def read_config
  config = YAML.load_file("config/migration.yml")
  @import_path = config["config"]["import_path"]
  @import_years = (config["config"]["import_years"]).split(",")
  @file_map_location = config["config"]["file_map_location"]
end

def log(msg,log_file)
  system("echo \"#{msg}\" >> #{log_file}")
end

encounters_to_void = []

encounter_ids = BartOneObservation.find(:all,
                  :select => 'DISTINCT encounter_id', 
                  :conditions => ['voided = ? AND date_created BETWEEN ? AND ?',
                                 1, Time.parse(START_DATE), 
                                 Time.parse(END_DATE)]).map(&:encounter_id)

encounters = BartOneEncounter.find(:all,
                         :include => :bart_one_observations,
                         :conditions => ['encounter_id IN (?)', encounter_ids])

encounters.each{|encounter|

  if encounter.voided?
    voiderer = User.find(encounter.bart_one_observations.first.voided_by).id rescue 1
    void_enc = {
     :patient_id => encounter.patient_id,
     :encounter_id => encounter.encounter_id,
     :encounter_datetime => encounter.encounter_datetime,
     :void_reason => encounter.bart_one_observations.first.void_reason,
     :date_voided => encounter.bart_one_observations.first.date_voided,
     :voided_by => voiderer
    }

    encounters_to_void << void_enc
    
  else
    log_message = "#{encounter.patient_id} - #{encounter.encounter_id}"
    log(log_message, LOG_FILE_UNVOIDED)
  end
}
#start voiding encounters
encounters_to_void.each{|enc|
  void_encounter = Encounter.find(
          :all,
          :conditions => ['encounter_datetime = ? AND patient_id = ?',
                          enc[:encounter_datetime], enc[:patient_id]]).first \
                      rescue nil

 unless void_encounter.blank?
   if not void_encounter.voided?
    void_encounter.void(enc[:void_reason], enc[:date_voided],enc[:voided_by])

    log_message = "#{void_encounter.patient_id}-#{void_encounter.encounter_id}"
    log(log_message, LOG_FILE_VOIDED)
   end
 end

}

log_message = "***********finished importing for #{START_DATE} AND #{END_DATE} ************"
log(log_message,LOG_MONITOR)
