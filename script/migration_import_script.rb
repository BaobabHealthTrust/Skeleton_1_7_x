require 'migrator'
require 'yaml'

Thread.abort_on_exception = true

LOG_FILE = RAILS_ROOT + '/log/migrator.log'

# set the right number of mongrels in config/mongrel_cluster.yml
# (e.g. servers: 4) and the starting port (port: 8000)
def read_config
  config = YAML.load_file("config/migration.yml")
  @import_path = config["config"]["import_path"]
  @import_years = (config["config"]["import_years"]).split(",")
  @file_map_location = config["config"]["file_map_location"]
end

def initialize_variables

  print_time("initialization started")
  
  read_config
 
  @bart_urls = {
    'first' => 'admin:test@localhost:7000',
    'second' => 'admin:test@localhost:7001',
    'third' => 'admin:test@localhost:7002',
    'fourth' => 'admin:test@localhost:7003'
  }

  @importers = {
    'general_reception.csv'      => ReceptionImporter,
    'update_outcome.csv'         => OutcomeImporter,
    'give_drugs.csv'             => DispensationImporter,
    'art_visit.csv'              => ArtVisitImporter,
    'hiv_first_visit.csv'        => ArtInitialImporter,
    'date_of_art_initiation.csv' => ArtInitialImporter,
    'height_weight.csv'          => VitalsImporter,
    'hiv_staging.csv'            => HivStagingImporter,
    'hiv_reception.csv'          => ReceptionImporter
  }

  @ordered_files = ['general_reception.csv', 'hiv_reception.csv',
    'hiv_first_visit.csv', 'date_of_art_initiation.csv', 'height_weight.csv',
    'hiv_staging.csv', 'art_visit.csv', 'give_drugs.csv', 'update_outcome.csv'
  ]
  @quarters = ['first','second','third','fourth']
  
  @start_time = Time.now
  
  print_time("Initialization ended")
end

def import_encounters(afile, import_path,bart_url)
	puts "-----Starting #{import_path}/#{afile} importing - #{Time.now}"

  importer = @importers[afile].new(import_path, @file_map_location)
	importer.create_encounters(afile, @bart_urls[bart_url])

	puts "-----#{import_path}/#{afile} imported after #{Time.now - @start_time}s"
end

def log(msg)
  system("echo \"#{msg}\" >> #{LOG_FILE}")
end

def print_time(message)
  @time = Time.now
  log "BART::Migrator-----#{message} at - #{@time} -----"
end

# mysqldump the database in current environment
def dump_db(year)
  config = ActiveRecord::Base.configurations[RAILS_ENV]
  username = config['username']
  password = config['password']
  host     = config['host']
  db       = config['database']
  sql_file = "#{RAILS_ROOT}/db/#{db}-#{year}.sql"

  cmd = "mysqldump -u #{username} -p#{password} -h #{host} #{db} > #{sql_file}"
  
  system(cmd)
end

threads = []

print_time("import utility started")

initialize_variables

@import_years.each do |year|
  threads = []
  @quarters.each do |quarter|
    threads << Thread.new(quarter) do |path|
      current_dir = @import_path + "/#{year}/#{quarter}"
      @ordered_files.each do |file|
        import_encounters(file, current_dir,quarter) #added quarter to ensure that we get the right bart_url_import_path
        log "BART-Migrator:***********File #{year}-#{quarter} #{file} imported ******************"
      end
      puts "BART-Migrator:*********#{year}-#{quarter} completed ******************"
      log "BART-Migrator:*********#{year}-#{quarter} completed ******************"
    end
  end

  threads.each {|thread| thread.join}
  puts "\nBART-Migrator:*************Finished importing Year: #{year} ********************"
  log "\nBART-Migrator:*************Finished importing Year: #{year} ********************"
  dump_db(year)
  log "\nDumped database at year #{year}"
end

print_time("----- Finished Import Script in #{Time.now - @start_time}s -----")

