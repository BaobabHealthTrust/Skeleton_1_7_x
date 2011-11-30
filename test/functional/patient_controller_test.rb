require File.dirname(__FILE__) + '/../test_helper'

class PatientsControllerTest < ActionController::TestCase
  fixtures :person, :person_name, :person_name_code, :person_address,
           :patient, :patient_identifier, :patient_identifier_type,
           :program, :concept, :concept_name, :encounter, :encounter_type

  def setup  
    @controller = PatientsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @patient = patient(:evan)  
  end

  context "Patient controller" do
    context "dashboard" do
      should "show the patient" do
        logged_in_as :mikmck, :registration do
          get :show, {:id => patient(:evan).id}
          assert_response :success
        end  
      end
    
      should "not show the pre art number if there is one and we are on the right location" do
        logged_in_as :mikmck, :registration do
          GlobalProperty.create(:property => 'dashboard.identifiers', :property_value => "{\"#{Location.current_location.id}\":[\"Pre ART Number\"]}")
          get :show, {:id => patient(:evan).id}
          assert_no_match /Pre ART Number/, @response.body
          assert_no_match /PART\-311/, @response.body
          assert_response :success
        end  
      end

      should "show the number of booked patients" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite 
          get :number_of_booked_patients, {:id => patient(:evan).id, :date => Date.today}
          assert_response :success
        end
      end

      should "get opdshow" do
        logged_in_as :mikmck, :registration do
          #TODO mastercard, opdcard, opdtreatment, mastercard_printable, patient_state
          #session[:mastercard_ids] = []
          get :treatment, {:patient_id => patient(:evan).patient_id}
          assert_response :success
        end
      end

      should "get the mastercard_modify" do
        logged_in_as :mikmck, :registration do
          get :mastercard_modify, {:id => patient(:evan).patient_id, :field => 'guardian'}
          assert_redirected_to("relationships/search?patient_id=#{patient(:evan).patient_id}")
          get :mastercard_modify, {:id => patient(:evan).patient_id, :field => 'occupation'}
          assert_response :success
        end
      end

      should "get the general_mastercard" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :general_mastercard, {:id => patient(:evan).patient_id, :type => 4}
          assert_response :success
        end
      end

      should "get the index view and show all necessary patient information" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :index, {:patient_id => patient(:evan).patient_id}
          assert_response :success
          assert_equal @response.body.include?("ARV-311"), true
          assert_equal @response.body.include?("HIV Status"), true
        end
      end

      should "relationships" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :relationships, {:patient_id => patient(:evan).patient_id}
          assert_response :success
        end
      end    
    
     should "guardians" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :guardians, {:patient_id => patient(:evan).patient_id}
          assert_response :success
        end
      end

    should "get the patient graph" do
      logged_in_as :mikmck, :registration do
       #TODO rewrite the test
       patient = patient(:evan)
       c_weight = PatientService.get_patient_attribute_value(patient, "current_weight")
       get :graph, {:patient_id => patient.patient_id, :data => "weight",
                    :current_weight => c_weight}
       assert_response :success
      end
    end

    should "mastercard" do
      logged_in_as :mikmck, :registration do
       #TODO rewrite the test
       patient = patient(:evan)
       get :mastercard_printable, {:patient_id => patient.patient_id}
       assert_response :success
      end
    end

    should "print mastercard" do
      logged_in_as :mikmck, :registration do
       #TODO rewrite the test
       patient = patient(:evan)
       get :print_mastercard, {:patient_id => patient.patient_id}
       assert_redirected_to("patients/mastercard?patient_id=#{patient(:evan).patient_id}")
      end
    end    

   should "demographics" do
      logged_in_as :mikmck, :registration do
       #TODO rewrite the test
       patient = patient(:evan)
       get :demographics, {:patient_id => patient.patient_id}
       assert_response :success
      end
    end

    should "overview" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :overview, {:patient_id => patient(:evan).patient_id}
          assert_response :success
        end
    end
      
    should "visit_history" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :visit_history, {:patient_id => patient(:evan).patient_id}
          assert_response :success
        end
    end

    should "past_visits_summary" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :past_visits_summary, {:patient_id => patient(:evan).patient_id}
          assert_response :success
        end
    end

    should "treatment_dashboard" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :treatment_dashboard, {:patient_id => patient(:evan).patient_id}
          assert_response :success
        end
    end

    should "guardians_dashboard" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :guardians_dashboard, {:patient_id => patient(:evan).patient_id}
          assert_response :success
        end
    end

   should "programs_dashboard" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :programs_dashboard, {:patient_id => patient(:evan).patient_id}
          assert_response :success
        end
    end

    should "recent_lab_orders" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :recent_lab_orders, {:patient_id => patient(:evan).patient_id}
          assert_response :success
        end
    end
           
    end
  end
end
