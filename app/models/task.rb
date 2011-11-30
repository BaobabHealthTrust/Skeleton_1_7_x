class Task < ActiveRecord::Base
  set_table_name :task
  set_primary_key :task_id
  include Openmrs

  private

end
