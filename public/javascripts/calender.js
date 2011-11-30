
  var date_set = [];
  var current_table_caption = null;
  var previous_selected = null;

  function setAttributes(){
    current_table_caption = document.getElementsByClassName('title')[0].innerHTML
    buttons_div = document.getElementById('buttons');
    buttons_div.innerHTML+= "<button onmousedown='nextMonth();' id='next' class='button navButton'><span>>|</span></button>";
    buttons_div.innerHTML+= "<button onmousedown='previousMonth();' id='previous' class='button navButton'><span>|<</span></button>";
    finish_button = document.getElementById('nextButton');
    finish_button.innerHTML = "<span>Finish</span>"
  }

  function addDate(set_date) {
    if (set_date == '' || set_date == null)                                     
      return                                                                    
  
    if ((new Date(set_date)) <= sessionDate) {
      showMessage("Selected date is less than set current clinic date");
      return 
    }

    td = document.getElementById(set_date);                                     
    if (td.style.background.match(/tomato/i) && !previous_selected == set_date) {                                 
      td.style.background = '#CADCEA';                                          
      document.getElementById("appointment_date").value = null;
    }else{                                                                      
      try {                
        td = document.getElementById(previous_selected);                                     
        td.style.background = '#CADCEA';                                          
      }catch(e) {}
      td = document.getElementById(set_date);                                     
      td.style.background = 'tomato';     
      previous_selected = set_date;
      document.getElementById("appointment_date").value = set_date;                                             
      showRecordedAppointments(set_date);         
      showDate();                              
    } 
    try { 
      set_emr_date = document.getElementById(setNextAppointmentDate);      
      if (!set_emr_date.style.background.match(/tomato/i)) {       
        set_emr_date.style.background = 'lightyellow';                      
      }                                        
    }catch(e) {}
  }

  function removeDate(set_date) {
    dates = date_set ; date_set = []
    for (i = 0 ; i < dates.length ; i++) {
      if (dates[i] != set_date)
        date_set.push(dates[i])
    }
  }

  function previousMonth(){
    if (current_table_caption == 'January') {                                   
      currYear = parseFloat(document.getElementById("app_date").innerHTML) - 1  
      document.getElementById("app_date").innerHTML = currYear ;                
      setDate = new Date("1/1/" + currYear);                                   
      chart();                                                   
      document.getElementById("app_date").innerHTML = currYear;                 
                                                                                
      while (current_table_caption != "December") {                             
        nextMonth();                                                            
      }
    } else if  (current_table_caption == 'December') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('November')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'November') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('October')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'October') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('September')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'September') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('August')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'August') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('July')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'July') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('June')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'June') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('May')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'May') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('April')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'April') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('March')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if (current_table_caption == 'March') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('February')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if (current_table_caption == 'February') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('January')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id;
    }
    msgBox = document.getElementById('information');                            
    year = document.getElementById('app_date').innerHTML;                       
    msgBox.innerHTML = "<span id ='app_date'>" + year + "</span>&nbsp;Total number of booked patients on this day:&nbsp;" + 0;
    try { 
      td = document.getElementById(setNextAppointmentDate);                                     
      td.style.background = "lightyellow";                                            
    } catch(e) {}

    try {                                                                          
      td = document.getElementById(previous_selected);      
      td.style.background = "tomato"; 
    } catch(e) {}
  }

  function nextMonth(){
    if (current_table_caption == 'January') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('February')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'February') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('March')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'March') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('April')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'April') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('May')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'May') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('June')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'June') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('July')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'July') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('August')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'August') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('September')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'September') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('October')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if  (current_table_caption == 'October') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('November')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if (current_table_caption == 'November') {
      month = document.getElementById(current_table_caption)
      month.style.display = 'none';
      next_month = document.getElementById('December')
      next_month.style.display = 'inline';
      current_table_caption = next_month.id
    } else if (current_table_caption == 'December') {                           
      current_table_caption = "January";                                        
      currYear = parseFloat(document.getElementById("app_date").innerHTML) + 1  
      document.getElementById("app_date").innerHTML = currYear                  
      setDate = new Date("1/1/" + currYear);                                   
      chart();                                                   
      try {                                                                     
        document.getElementById("year").innerHTML = currYear;                   
      } catch(e) {}                                                             
    }                                                                           
    msgBox = document.getElementById('information');                            
    year = document.getElementById('app_date').innerHTML;                       
    msgBox.innerHTML = "<span id ='app_date'>" + year + "</span>&nbsp;Total number of booked patients on this day:&nbsp;" + 0;
                                                                                 
    try {                                                                          
      td = document.getElementById(setNextAppointmentDate);                                     
      td.style.background = "lightyellow";
    } catch(e) {}

    try {                                                                          
      td = document.getElementById(previous_selected);      
      td.style.background = "tomato"; 
    } catch(e) {}
  }

  function setAppointmentDate(){
    return
    selected_dates = "<%= @clinic_holidays %>"
    if (selected_dates != ''){
      change_attribute = 0;
      selected_dates = selected_dates.split(',')
      for(i = 0 ; i < selected_dates.length ; i++){
        for(x = 0 ; x < date_set.length ; x++){
          if(selected_dates[i].substring(5,10) == date_set[x].substring(5,10)){
            change_attribute+= 1;
          }
        }
      }

      if (change_attribute == selected_dates.length && change_attribute == date_set.length){
        document.location = "/clinic";
        return;
      }
    }


    submitForm = document.createElement("FORM");
    submitForm.setAttribute("type","hidden");
    document.body.appendChild(submitForm);
    submitForm.method = "POST";
    newElement = document.createElement("input")
    newElement.setAttribute("name",'holidays')
    newElement.setAttribute("type","hidden");
    submitForm.appendChild(newElement);
    newElement.value = date_set.join(',');
    submitForm.action= "/properties/create_clinic_holidays";
    submitForm.submit();
  }

  function daysInMonth(month,year) {
    var m = [31,28,31,30,31,30,31,31,30,31,30,31];
    if (month != 2) return m[month - 1];
    if (year%4 != 0) return m[1];
    if (year%100 == 0 && year%400 != 0) return m[1];
    return m[1] + 1;
  } 

  function currMonth(month_num) {                                            
    var month = new Array(12);                                                    
    month[0]="January";                                                         
    month[1]="February";                                                        
    month[2]="March";                                                           
    month[3]="April";                                                           
    month[4]="May";                                                             
    month[5]="June";                                                            
    month[6]="July";                                                            
    month[7]="August";                                                          
    month[8]="September";                                                       
    month[9]="October";                                                         
    month[10]="November";                                                       
    month[11]="December";                                                       
                                                                                
    return month[month_num];                                                    
  }

   function chart() {
    nextAppointmentDate = new Date(setDate);
    var chart = ''
    var container = "<div class = 'container'>\n"
    var number = 1
    while (number < 13) {
      var startDate = number + "/1/" + nextAppointmentDate.getFullYear();
      startDate = new Date(startDate);
      var daysIn = daysInMonth((startDate.getMonth() + 1) , startDate.getFullYear());
      var endDate = number + "/" + daysIn + "/" + nextAppointmentDate.getFullYear();
      number++;
      endDate = new Date(endDate);

      chart+="<table id='" + currMonth(endDate.getMonth()) + "' class='months'>";
      chart+="\n<caption class = 'title'>" + currMonth(endDate.getMonth()) + "</caption>"
      chart+="\n<tr>\n<th>Sunday</th>\n<th>Monday</th>\n<th>Tuesday</th>\n<th>Wednesday</th>"
      chart+="\n<th>Thursday</th>\n<th>Friday</th>\n<th>Saturday</th>\n</tr>"
 
      while (startDate <= endDate) { 
        var sunday = '' ; var monday = '' ; var tuesday = '';
        var wednesday = '' ; var thursday = ''; 
        var friday = '' ; var saturday = '';

        var day = startDate.getDay();
        var wkDays = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];
        day = wkDays[day];


        if (day == 'Monday') {
          monday = startDate.getDate(); 
        }else if (day == 'Tuesday') {
          tuesday = startDate.getDate();  
        }else if (day == 'Wednesday') {  
          wednesday = startDate.getDate();  
        }else if (day == 'Thursday') {  
          thursday = startDate.getDate();  
        }else if (day == 'Friday') { 
          friday = startDate.getDate();  
        }else if (day == 'Saturday') {  
          saturday = startDate.getDate();  
        }else if (day == 'Sunday') {  
          sunday = startDate.getDate();  
        }

        try {

        if (monday) {
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            tuesday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            wednesday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            thursday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            friday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            saturday = startDate.getDate()
          }
        } else if (tuesday) {
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            wednesday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))  
            thursday = startDate.getDate()
          }  
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            friday = startDate.getDate()
          }  
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            saturday = startDate.getDate()
          }
        } else if (wednesday) {
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            thursday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            friday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            saturday = startDate.getDate()
          }
        } else if (thursday) {
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            friday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            saturday = startDate.getDate()
          }
        } else if (friday) {
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            saturday = startDate.getDate()
          }
        } else if (sunday) {
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            monday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            tuesday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            wednesday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            thursday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            friday = startDate.getDate()
          }
          if (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()) <= endDate) {
            startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
            saturday = startDate.getDate()
          }
        }   

        }catch(e) {}
    
        try{
          sunday_str = new Date((startDate.getMonth() + 1) + "/" + sunday + "/" + startDate.getFullYear())
          sunday_str = dateFormat(sunday_str,"yyyy-mm-dd");
        }catch(e) {sunday_str = ''}

        try{
          monday_str = new Date((startDate.getMonth() + 1) + "/" + monday + "/" + startDate.getFullYear())
          monday_str = dateFormat(monday_str,"yyyy-mm-dd");
        }catch(e) {monday_str = ''}

        try{
          tuesday_str = new Date((startDate.getMonth() + 1) + "/" + tuesday + "/" + startDate.getFullYear())
          tuesday_str = dateFormat(tuesday_str,"yyyy-mm-dd");
        }catch(e) {tuesday_str = ''}

        try{
          wednesday_str = new Date((startDate.getMonth() + 1) + "/" + wednesday + "/" + startDate.getFullYear())
          wednesday_str = dateFormat(wednesday_str,"yyyy-mm-dd");
        }catch(e) {wednesday_str = ''}

        try{
          thursday_str = new Date((startDate.getMonth() + 1) + "/" + thursday + "/" + startDate.getFullYear())
          thursday_str = dateFormat(thursday_str,"yyyy-mm-dd");
        }catch(e) {thursday_str = ''}

        try{
          friday_str = new Date((startDate.getMonth() + 1) + "/" + friday + "/" + startDate.getFullYear())
          friday_str = dateFormat(friday_str,"yyyy-mm-dd");
        }catch(e) {friday_str = ''}

        try{
          saturday_str = new Date((startDate.getMonth() + 1) + "/" + saturday + "/" + startDate.getFullYear())
          saturday_str = dateFormat(saturday_str,"yyyy-mm-dd");
        }catch(e) {saturday_str = ''}




        chart+="\n<tr>"
        chart+= '\n<td onMouseDown="addDate(\''+sunday_str+'\');" class="dates" id="'+sunday_str+'">' +sunday+ "</td>";
        chart+= '\n<td onMouseDown="addDate(\''+monday_str+'\');" class="dates" id="'+monday_str+'">' +monday+ "</td>";
        chart+= '\n<td onMouseDown="addDate(\''+tuesday_str+'\');" class="dates" id="'+tuesday_str+'">' +tuesday+ "</td>";
        chart+= '\n<td onMouseDown="addDate(\''+wednesday_str+'\');" class="dates" id="'+wednesday_str+'">' +wednesday+ "</td>";
        chart+= '\n<td onMouseDown="addDate(\''+thursday_str+'\');" class="dates" id="'+thursday_str+'">' +thursday+ "</td>";
        chart+= '\n<td onMouseDown="addDate(\''+friday_str+'\');" class="dates" id="'+friday_str+'">' +friday+ "</td>";
        chart+= '\n<td onMouseDown="addDate(\''+saturday_str+'\');" class="dates" id="'+saturday_str+'">' +saturday+ "</td>";
        chart+="\n</tr>"

        try {
          startDate = (new Date((startDate.getMonth() + 1) + "/" + (startDate.getDate() + 1) + "/" + startDate.getFullYear()))
        }catch(e){
          break;  
        }
      }
        chart+='\n</table>'
    }
    container += chart + "\n</div><br />";
    element = document.getElementsByClassName("inputFrameClass")[0];
    element.innerHTML = container;
    element.style.cssText = "611px !important";
  }

//............................................................................



  function showRecordedAppointments(setdate) {                                  
    msgBox = $('information');                                                  
    msgBox.style.display = 'block';                                             
    new Ajax.Request("/patients/number_of_booked_patients?date=" + setdate ,{method:'get',onSuccess: function(transport){
      count = JSON.parse(transport.responseText) || "";                         
      year = parseFloat(document.getElementById("app_date").innerHTML);         
      if (count) {                                                              
        msgBox.innerHTML = "<span id ='app_date'>" + year + "</span>&nbsp;Total number of booked patients on this day:&nbsp;" + count;
      }else{                                                                    
        msgBox.innerHTML = "<span id ='app_date'>" + year + "</span>&nbsp;Total number of booked patients on this day:&nbsp;" + 0;
      }                                                                         
    }});                                                                        
  }

