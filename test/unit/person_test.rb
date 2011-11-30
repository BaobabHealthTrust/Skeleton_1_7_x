require File.dirname(__FILE__) + '/../test_helper'

class PersonTest < ActiveSupport::TestCase
  #Some methods have been removed from person model to patient_service module
  #as part od code cleaning. patient_service is in lib folder.
  #Hence the 'PatientService.' in front of those methods throughout this unit test.

  context "Person" do
    fixtures :person, :person_name, :person_name_code,
             :person_address, :obs, :patient, :person_attribute,
             :person_attribute_type

    should "be valid" do
      assert Person.make.valid?
    end

    should "return the age" do
      p = person(:evan)
      assert_equal PatientService.age(p, today = "2008-06-07".to_date), 25

      p.birthdate = nil    
      assert_nil PatientService.age(p, today = "2008-06-07".to_date)
    end

    should "return the age and increase it by one if the birthdate was estimated and you are checking during the year it was created" do 
      p = Person.make(:birthdate => "2000-07-01".to_date, :birthdate_estimated => 1)
      p.date_created = "2008-01-01".to_date
      assert_equal PatientService.age(p, today = "2008-06-07".to_date), 8

      p = Person.make(:birthdate => "2000-07-01".to_date, :birthdate_estimated => 1)
      p.date_created = "2000-01-01".to_date
      assert_equal PatientService.age(p, today = "2008-06-07".to_date), 7
    end

    should "format the birthdate" do
      assert_equal PatientService.birthdate_formatted(person(:evan)), "09/Jun/1982"
assert_equal PatientService.birthdate_formatted(Person.make(:birthdate => "2000-07-01".to_date, :birthdate_estimated=> 1)), "??/???/2000"

      assert_equal PatientService.birthdate_formatted(Person.make(:birthdate => "2000-06-15".to_date, :birthdate_estimated => 1)), "??/Jun/2000"

      assert_equal PatientService.birthdate_formatted(Person.make(:birthdate => "2000-07-01".to_date, :birthdate_estimated => 0)), "01/Jul/2000"     
    end
    
    should "set the birthdate" do
      p = person(:evan)
      should_raise do PatientService.set_birthdate(p) end # no year

      should_raise do PatientService.set_birthdate(p, 1982, 2, 30) end # bad day

      PatientService.set_birthdate(p, 1982)
      assert_equal PatientService.birthdate_formatted(p), "??/???/1982"
      PatientService.set_birthdate(p, 1982, 6)
      assert_equal PatientService.birthdate_formatted(p), "??/Jun/1982"
      PatientService.set_birthdate(p, 1982, 6, 9)
      assert_equal PatientService.birthdate_formatted(p), "09/Jun/1982"

      PatientService.set_birthdate(p, 1982, "Unknown", "Unknown")
      assert_equal PatientService.birthdate_formatted(p), "??/???/1982"

      PatientService.set_birthdate(p, 1982, "Jun", 9)
      assert_equal PatientService.birthdate_formatted(p), "09/Jun/1982"

      PatientService.set_birthdate(p,1982, "June", 9)
      assert_equal PatientService.birthdate_formatted(p), "09/Jun/1982"
    end
    
    should "set the birthdate by age" do 
      p = person(:evan)
      PatientService.set_birthdate_by_age(p, 22, "2008-06-07".to_date)
      assert_equal PatientService.birthdate_formatted(p), "??/???/1986"    
    end
    
    should "get the person's age in months" do
      Date.stubs(:today).returns(Date.parse("2008-08-16"))
      p = person(:evan)
      assert_equal PatientService.age_in_months(p), 314
    end
      
    should "return the name" do
      assert_equal PatientService.name(person(:evan)), "Evan Waters"    
    end
      
    should "return the address" do
      assert_equal person(:evan).addresses.first.city_village, "Katoleza"
    end
    
    should "return the first preferred name" do
      p = person(:evan)
      p.names << PersonName.create(:given_name => "Mr. Cool")
      p.names << PersonName.create(:given_name => "Sunshine", :family_name => "Cassidy", :preferred => 1)
      p.save!

      assert_equal PatientService.name(Person.find(:first, :include => :names)), "Sunshine Cassidy"
    end
    
    should "return the first preferred address" do
      p = person(:evan)
      p.addresses << PersonAddress.create(:address1 => 'Sunshine Underground', :city_village => 'Lilongwe')
      p.addresses << PersonAddress.create(:address1 => 'Staff Housing', :city_village => 'Neno', :preferred => 1)
      p.save!
      assert_equal Person.find(:first, :include => :addresses).addresses.first.city_village, "Neno"
    end

    should "refer to the person's names but not include voided names" do
      p = person(:evan)
      PersonName.create(:given_name => "Sunshine", :family_name => "Cassidy", :preferred => 1, :person_id => p.person_id, :voided => 1)
      assert_not_equal Person.find(:first, :include => :names).names, "Sunshine Cassidy"
    end
    
    should "refer to the person's addresses but not include voided addresses" do
      p = person(:evan)
      PersonAddress.create(:address1 => 'Sunshine Underground', :city_village => 'Lilongwe', :preferred => 1, :person_id => p.person_id, :voided => 1)
      assert_not_equal Person.find(:first, :include => :addresses).addresses.first.city_village, "Lilongwe"
    end

    should "refer to the person's observations but not include voided observations" do
      o = obs(:evan_vitals_height)
      o.void("End of the world")
      p = person(:evan)
      assert p.observations
      assert_equal p.observations.count, 1
    end
    
    should "refer to the corresponding patient" do
      p = person(:evan)
      assert_equal p.patient, patient(:evan)
    end

    should "return a hash with correct name" do
      p = person(:evan)
      name_data = {
          "given_name" => "Evan",
          "family_name" => "Waters",
          "family_name2" => "Murray"
      }
      demographics = PatientService.demographics(p)
      assert_equal demographics["person"]["names"], name_data
    end

    should "return a hash with correct address" do
      p = person(:evan)
      data = {
        "address1" => "Green Snake Way",
        "address2" => "Friendship House",
        "county_district" => "Checkuchecku",
        "city_village" => "Katoleza"
      }
      demographics = PatientService.demographics(p)
      assert_equal demographics["person"]["addresses"], data
    end

   should "return a hash with correct person attributes" do
      p = person(:evan)
      data = {
        "occupation" => "Other",
        "cell_phone_number" => "0999123456"
      }
      demographics = PatientService.demographics(p)
      assert_equal demographics["person"]["attributes"], data
    end

    should "return a hash with correct patient" do
      p = person(:evan)
      data = {
        "identifiers" => {
            "National id" => "P1701210013",
            "ARV Number" => "ARV-311",
            #"Pre ART Number" => "PART-311",
            "Filing number"=>"FN3300001"
        }
      }
      demographics = PatientService.demographics(p)
      assert_equal demographics["person"]["patient"], data
    end

    should "return a hash that represents a patients demographics" do
      p = person(:evan)

      evan_demographics = {"person" => {
        "addresses"=> {"address2" => "Friendship House",
                       "city_village" => "Katoleza",
                       "address1" => "Green Snake Way",
                       "county_district" => "Checkuchecku"},
        "birth_month" => 6,
        "attributes" => {"occupation" => "Other", "cell_phone_number" => "0999123456"},
        "patient" => {"identifiers" => {"National id" => "P1701210013",
                                      #"Pre ART Number" => "PART-311",
                                      "ARV Number" => "ARV-311",
                                      "Filing number"=>"FN3300001"}},
        "gender" => "M",
        "birth_day" => 9,
        "date_changed" => "Sat Jan 01 00:00:00 +0200 2000",
        "names" =>
              {"family_name2" => "Murray", "family_name" => "Waters", "given_name" => "Evan"},
        "birth_year" => 1982}}

    assert_equal PatientService.demographics(p), evan_demographics
    end

    should "return demographics with appropriate estimated birthdates" do
      p = person(:evan)

      assert_equal PatientService.demographics(p)["person"]["birth_day"], 9

      p.birthdate_estimated = 1
      assert_equal PatientService.demographics(p)["person"]["birth_day"], "Unknown"

      PatientService.set_birthdate(p,p.birthdate.year,p.birthdate.month,"Unknown")
      assert_equal PatientService.demographics(p)["person"]["birth_year"], 1982
      assert_equal PatientService.demographics(p)["person"]["birth_month"], 6
      assert_equal PatientService.demographics(p)["person"]["birth_day"], "Unknown"

      PatientService.set_birthdate(p,p.birthdate.year,"Unknown","Unknown")
      assert_equal PatientService.demographics(p)["person"]["birth_year"], 1982
      assert_equal PatientService.demographics(p)["person"]["birth_month"], "Unknown"
      assert_equal PatientService.demographics(p)["person"]["birth_day"], "Unknown"
    end

=begin
    should "create a patient with nested parameters formatted as if they were coming from a form" do
      demographics = person(:evan).demographics
      parameters = demographics.to_param
      # TODO:
      # better test needed with incliusion of date_changed as on creating
      # new patient registers new 'date_changed'
      assert_equal Person.create_from_form(Rack::Utils.parse_nested_query(parameters)["person"]).demographics["person"]["national_id"], demographics["person"]["national_id"]
    end
=end

    should "not crash if there are no demographic servers specified" do
      should_not_raise do
        GlobalProperty.delete_all(:property => 'remote_demographics_servers')
        demographics = PatientService.demographics(person(:evan))
        PatientService.find_remote_person(demographics)
        #Person.find_remote(person(:evan).demographics)
      end
    end

    should "include a remote demographics servers global property" do
      assert !GlobalProperty.find(:first, :conditions => {:property => "remote_demographics_servers"}).nil?, "Current GlobalProperties #{GlobalProperty.find(:all).map{|gp|gp.property}.inspect}"
    end
=begin
    should "be able to ssh without password to remote demographic servers" do
      GlobalProperty.find(:first, :conditions => {:property => "remote_demographics_servers"}).property_value.split(/,/).each{|hostname|
        ssh_result = `ssh -o ConnectTimeout=2 #{hostname} wget --version `
        assert ssh_result.match /GNU Wget/
      }
    end
=end

=begin
    should "be able to check remote servers for person demographics" do
      # IMPLEMENTAION OF THE TEST
      # =========================
      # - set up a clone of mateme to run on localhost port 80
      # - change the demographics on the clone eg national id to
      #   an id that is not on this one
      # - request for demographics with the new national id
      # - check if we get expected demographics
      remote_demographics={ 
        "person" => {
          "date_changed"=>"Sat Jan 01 00:00:00 +0200 2000",
          "gender" => "M",
          "birth_year" => 1982,
          "birth_month" => 6,
          "birth_day" => 9,
          "names" => {
            "given_name" => "Evan",
            "family_name" => "Waters",
            "family_name2" => ""
          },
          "addresses" => {
            "county_district" => "",
            "city_village" => "Katoleza"
          },
          "patient" => {
            "identifiers" => {
              "National id" => "P1701210014",
              "ARV Number" => "ARV-411",
              "Pre ART Number" => "PART-411"
            }
          }
        }
      }
      assert_equal Person.find_remote(remote_demographics)["person"], remote_demographics["person"]
    end
=end

    should "be able to retrieve person data by their demographic details" do
      demographics = PatientService.demographics(person(:evan))
      assert_equal PatientService.find_person_by_demographics(demographics).first, person(:evan)
    end

    should "be able to retrieve person data with their national id" do
      demographic_national_id_only = {"person" => {"patient" => {"identifiers" => {"National id" => "P1701210013"} }}}
      assert_equal PatientService.find_person_by_demographics(demographic_national_id_only).first, person(:evan)
    end

  end
end
