/* jshint strict: false */
/* global $: false, google: false */
//
// Red, White, and Blue JavaScript 
// for EECS 339 Project A at Northwestern University
//
// Originally by Peter Dinda
//
//
// Global state
//
// html    - the document itself ($. or $(document).)
// map     - the map object
// usermark- marks the user's position on the map
// markers - list of markers on the current map (not including the user position)
//
//

//
// When the document has finished loading, the browser
// will invoke the function supplied here.  This
// is an anonymous function that simply requests that the 
// brower determine the current position, and when it's
// done, call the "Start" function  (which is at the end
// of this file)
// 
//
$(document).ready(function() {
	navigator.geolocation.getCurrentPosition(Start);
});

// Global variables
var map, usermark, markers = [],

// UpdateMapById draws markers of a given category (id)
// onto the map using the data for that id stashed within 
// the document.
UpdateMapById = function(id, tag) {
// the document division that contains our data is #committees 
// if id=committees, and so on..
// We previously placed the data into that division as a string where
// each line is a separate data item (e.g., a committee) and
// tabs within a line separate fields (e.g., committee name, committee id, etc)
// 
// first, we slice the string into an array of strings, one per 
// line / data item

if ($("#"+id).html()) {
  	var rows  = $("#"+id).html().split("\n");

  // then, for each line / data item
  	for (var i=0; i<rows.length; i++) {
  // we slice it into tab-delimited chunks (the fields)
  		var cols = rows[i].split("\t"),
  // grab specific fields like lat and long
  			lat = cols[0],
  			long = cols[1];

  // then add them to the map.   Here the "new google.maps.Marker"
  // creates the marker and adds it to the map at the lat/long position
  // and "markers.push" adds it to our list of markers so we can
  // delete it later 
  		markers.push(new google.maps.Marker({
  			map: map,
  			position: new google.maps.LatLng(lat,long),
  			title: tag+"\n"+cols.join("\n")
  		}));
  	}
  }
},

//
// ClearMarkers just removes the existing data markers from
// the map and from the list of markers.
//
ClearMarkers = function() {
	// clear the markers
	while (markers.length>0) {
		markers.pop().setMap(null);
	}
},

//
// UpdateMap takes data sitting in the hidden data division of 
// the document and it draws it appropriately on the map
//
UpdateMap = function() {
// We're consuming the data, so we'll reset the "color"
// division to white and to indicate that we are updating
	var color = $("#color");
	color.css("background-color", "white")
		.html("<b><blink>Updating Display...</blink></b>");

// Remove any existing data markers from the map
	ClearMarkers();

// Then we'll draw any new markers onto the map, by category
// Note that there additional categories here that are 
// commented out...  Those might help with the project...
//
	UpdateMapById("committee_data","COMMITTEE");
	UpdateMapById("candidate_data","CANDIDATE");
	UpdateMapById("individual_data", "INDIVIDUAL");
	UpdateMapById("opinion_data","OPINION");

// When we're done with the map update, we mark the color division as
// Ready.
	color.html("Ready");

// The hand-out code doesn't actually set the color according to the data
// (that's the student's job), so we'll just assign it a random color for now
	if (Math.random()>0.5) {
		color.css("background-color", "blue");
	} else {
		color.css("background-color", "red");
	}

},

//
// NewData is called by the browser after any request
// for data we have initiated completes
//
NewData = function(data) {
// All it does is copy the data that came back from the server
// into the data division of the document.   This is a hidden 
// division we use to cache it locally
	$("#data").html(data);
// Now that the new data is in the document, we use it to
// update the map
	UpdateMap();
},

// This function throttles the function passed in to it
// The returned, throttled function is bound to maps in Start
// For this application, we are throttling ViewShift 
// This code was modified from http://sampsonblog.com/749/simple-throttle-function
Throttler = function(called_func, delay) {
	var waiting = false;
	return function() {
		if (!waiting) {
			called_func();
			// set waiting back to true, because we just ran called_func (ViewShift)
			waiting = true;
			setTimeout(function() {
				waiting = false;
			}, delay);
		}
	}
},

//
// The Google Map calls us back at ViewShift when some aspect
// of the map changes (for example its bounds, zoom, etc)
//
ViewShift = function(e,is_aggregate) {
// We determine the new bounds of the map
	var bounds = map.getBounds(),
		ne = bounds.getNorthEast(),
		sw = bounds.getSouthWest();

// Now we need to update our data based on those bounds
// first step is to mark the color division as white and to say "Querying"
	$("#color").css("background-color","white")
		.html("<b><blink>Querying...("+ne.lat()+","+ne.lng()+") to ("+sw.lat()+","+sw.lng()+")</blink></b>");

// Now we make a web request.   Here we are invoking rwb.pl on the 
// server, passing it the act, latne, etc, parameters for the current
// map info, requested data, etc.
// the browser will also automatically send back the cookie so we keep
// any authentication state
// 
// This *initiates* the request back to the server.  When it is done,
// the browser will call us back at the function NewData (given above)


// checks if opinions, individuals box is checked
	var whatstring = "";
  	
	if ($("input[type='checkbox'][name='committees']").is(':checked')) {
    		whatstring = "committees";
    		localStorage.committee = "true";
  	}
  	else 
    		localStorage.committee = "";

	if ($("input[type='checkbox'][name='candidates']").is(':checked')) {
    		if (whatstring)
			whatstring += ",candidates";
		else
			whatstring = "candidates";

    		localStorage.candidate = "true";
  	}
  	else 
    		localStorage.candidate = "";

	if ($("input[type='checkbox'][name='individuals']").is(':checked')) {
    		if (whatstring)
			whatstring += ",individuals";
		else
			whatstring = "individuals";

		localStorage.individual = "true";
  	}
  	else 
  		localStorage.individual = "";

	if ($("input[type='checkbox'][name='opinions']").is(':checked')) {
    		if (whatstring)
			whatstring += ",opinions";
    		else
			whatstring = "opinions";
		
		localStorage.opinion = "true";
  	}
  	else 
    		localStorage.opinion = "";
  
// create string of cycles to get election data for
	var whatcycles = [];
	
	$("input[type='checkbox'][name='cycle']:checked").each(function(){
		whatcycles.push($(this).attr('value'));
	});
  	whatcycles = whatcycles.toString();
  	// console.log(is_aggregate);
//checks to see if aggregate function should get called, or near
	if (is_aggregate) {
		$.get("rwb.pl",
		{
			act:	"aggregate",
			latne:	ne.lat(),
			longne:	ne.lng(),
			latsw:	sw.lat(),
			longsw:	sw.lng(),
			format:	"raw",
			what:	whatstring,
			cycle:  whatcycles
		}, function(data) {
			$("#summary").html(data);
		});
	} 
	else {
		$.get("rwb.pl",
		{
			act:	"near",
			latne:	ne.lat(),
			longne:	ne.lng(),
			latsw:	sw.lat(),
			longsw:	sw.lng(),
			format:	"raw",
			what:	whatstring,
			cycle:  whatcycles
		}, NewData);
	}	
},



//
// If the browser determines the current location has changed, it 
// will call us back via this function, giving us the new location
//
Reposition = function(pos) {
// We parse the new location into latitude and longitude
	var lat = pos.coords.latitude,
		long = pos.coords.longitude;

// ... and scroll the map to be centered at that position
// this should trigger the map to call us back at ViewShift()
	map.setCenter(new google.maps.LatLng(lat,long));
// ... and set our user's marker on the map to the new position
	usermark.setPosition(new google.maps.LatLng(lat,long));

// each time user moves map, update their position for opinion data form
 	$("input[type='hidden'][name='lat']").val(lat);
 	$("input[type='hidden'][name='long']").val(long);

},


//
// The start function is called back once the document has 
// been loaded and the browser has determined the current location
//
Start = function(location) {
// Parse the current location into latitude and longitude        
	var lat = location.coords.latitude,
	    long = location.coords.longitude,
	    acc = location.coords.accuracy,
// Get a pointer to the "map" division of the document
// We will put a google map into that division
	    mapc = $("#map");

// Create a new google map centered at the current location
// and place it into the map division of the document
	map = new google.maps.Map(mapc[0],
		{
			zoom: 16,
			center: new google.maps.LatLng(lat,long),
			mapTypeId: google.maps.MapTypeId.HYBRID
		});

// create a marker for the user's location and place it on the map
	usermark = new google.maps.Marker({ map:map,
		position: new google.maps.LatLng(lat,long),
		title: "You are here"});

// set user's position for opinion data form
 	$("input[type='hidden'][name='lat']").val(lat);
 	$("input[type='hidden'][name='long']").val(long);

//remembers what data was checked on page reload
 	if (localStorage.committee)
		$("input[type='checkbox'][name='committees']").attr('checked','checked');
  	if (localStorage.opinion)
  	  	$("input[type='checkbox'][name='opinions']").attr('checked','checked');
  	if (localStorage.individual)
  	  	$("input[type='checkbox'][name='individuals']").attr('checked','checked');
  	if (localStorage.candidate)
		$("input[type='checkbox'][name='candidates']").attr('checked','checked');

// clear list of markers we added to map (none yet)
// these markers are committees, candidates, etc
	markers = [];

// set the color for "color" division of the document to white
// And change it to read "waiting for first position"
	$("#color").css("background-color", "white")
		.html("<b><blink>Waiting for first position</blink></b>");


// This assigns the output of Throttler to a function
// This new throttled ViewShift function will get bound to map changes
	var ThrottledViewShift = Throttler(ViewShift, 1000);

//
// These lines register callbacks.   If the user scrolls the map, 
// zooms the map, etc, then our function "ViewShift" (defined above
// will be called after the map is redrawn
//
	google.maps.event.addListener(map,"bounds_changed",ThrottledViewShift);
	google.maps.event.addListener(map,"center_changed",ThrottledViewShift);
	google.maps.event.addListener(map,"zoom_changed",ThrottledViewShift);

// Don't bind this to ThrottledViewShift, because when somebody checks a 
	// checkbox, it should update immediately, not wait one second
// when checkbox gets selected, update map
 	$("input[type='checkbox']").click(ViewShift);

// Since this is a separate button and function, we don't need to throttle it,
	// because it is only getting called when the user clicks the button
// when aggregate gets clicked, calculate aggregate
	$("button#aggregate").click(function(e) { ViewShift(e,true); });

//
// Finally, tell the browser that if the current location changes, it
// should call back to our "Reposition" function (defined above)
//
	navigator.geolocation.watchPosition(Reposition);
};
