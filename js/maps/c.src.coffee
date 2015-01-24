###
# The main coffeescript file for administrative stuff
# Triggered from admin-page.html
###
adminParams = new Object()
adminParams.apiTarget = "admin_api.php"
adminParams.loginDir = "admin/"
adminParams.loginApiTarget = "#{adminParams.loginDir}async_login_handler.php"

loadAdminUi = ->
  ###
  # Main wrapper function. Checks for a valid login state, then
  # fetches/draws the page contents if it's OK. Otherwise, boots the
  # user back to the login page.
  ###
  try
    verifyLoginCredentials (data) ->
      # Post verification
      $("article").html("<h3>Welcome, #{$.cookie("ssarherps_name")} <paper-icon-button icon='settings-applications' class='click' data-url='#{data.login_url}'></paper-icon-button></h3><div id='admin-actions-block'><div class='bs-callout bs-callout-info'><p>Please be patient while the administrative interface loads.</p></div></div>")
      ###
      # Render out the admin UI
      # We want a search box that we pipe through the API
      # and display the table out for editing
      ###
      searchForm = "<form id=\"admin-search-form\" onsubmit=\"event.preventDefault()\">\n\t<div>\n\t\t<paper-input label=\"Search for species\" id=\"admin-search\" name=\"admin-search\" required autofocus floatingLabel class=\"col-xs-7 col-sm-8\"></paper-input>\n\t\t<paper-fab id=\"do-admin-search\" icon=\"search\" raisedButton class=\"materialblue\"></paper-fab>\n\t</div>\n</form><div id='search-results'></div>"
      $("#admin-actions-block").html(searchForm)
      $("#admin-search-form").submit (e) ->
        e.preventDefault()
      $("#admin-search").keypress (e) ->
        if e.which is 13 then renderAdminSearchResults()
      $("#do-admin-search").click ->
        renderAdminSearchResults()
      false
  catch e
    $("article").html("<div class='bs-callout bs-callout-danger'><h4>Application Error</h4><p>There was an error in the application. Please refresh and try again. If this persists, please contact administration.</p></div>")
  false


verifyLoginCredentials = (callback) ->
  ###
  # Checks the login credentials against the server.
  # This should not be used in place of sending authentication
  # information alongside a restricted action, as a malicious party
  # could force the local JS check to succeed.
  # SECURE AUTHENTICATION MUST BE WHOLLY SERVER SIDE.
  ###
  hash = $.cookie("ssarherps_auth")
  secret = $.cookie("ssarherps_secret")
  link = $.cookie("ssarherps_link")
  args = "hash=#{hash}&secret=#{secret}&dblink=#{link}"
  $.post(adminParams.loginApiTarget,args,"json")
  .done (result) ->
    if result.status is true
      callback(result)
    else
      goTo(result.login_url)
  .fail (result,status) ->
    # Throw up some warning here
    $("article").html("<div class='bs-callout-danger bs-callout'><h4>Couldn't verify login</h4><p>There's currently a server problem. Try back again soon.</p>'</div>")
    console.log(result,status)
    false
  false


renderAdminSearchResults = (containerSelector = "#search-results") ->
  ###
  # Takes parts of performSearch() but only in the admin context
  ###
  s = $("#admin-search").val()
  if isNull(s)
    toastStatusMessage("Please enter a search term")
    return false
  animateLoad()
  $("#admin-search").blur()
  # Remove periods from the search
  s = s.replace(/\./g,"")
  s = prepURI(s)
  args = "q=#{s}&loose=true"
  $.get(searchParams.targetApi,args,"json")
  .done (result) ->
    if result.status isnt true
      toastStatusMessage(result.human_error)
      return false
    # Now, take the results and format them
    data = result.result
    html = ""
    htmlHead = "<table id='cndb-result-list' class='table table-striped table-hover'>\n\t<tr class='cndb-row-headers'>"
    htmlClose = "</table>"
    # We start at 0, so we want to count one below
    targetCount = toInt(result.count)-1
    colClass = null
    bootstrapColCount = 0
    $.each data, (i,row) ->
      if toInt(i) is 0
        j = 0
        htmlHead += "\n<!-- Table Headers - #{Object.size(row)} entries -->"
        $.each row, (k,v) ->
          niceKey = k.replace(/_/g," ")
          if k is "genus" or k is "species" or k is "subspecies"
            htmlHead += "\n\t\t<th class='text-center'>#{niceKey}</th>"
            bootstrapColCount++
          j++
          if j is Object.size(row)
            htmlHead += "\n\t\t<th class='text-center'>Edit</th>\n\t</tr>"
            bootstrapColCount++
            htmlHead += "\n<!-- End Table Headers -->"
            console.log("Got #{bootstrapColCount} display columns.")
            bootstrapColSize = roundNumber(12/bootstrapColCount,0)
            colClass = "col-md-#{bootstrapColSize}"
      taxonQuery = "#{row.genus}+#{row.species}"
      if not isNull(row.subspecies)
        taxonQuery = "#{taxonQuery}+#{row.subspecies}"
      htmlRow = "\n\t<tr id='cndb-row#{i}' class='cndb-result-entry' data-taxon=\"#{taxonQuery}\">"
      l = 0
      $.each row, (k,col) ->
        if isNull(row.genus)
          # Next iteration
          return true
        if k is "genus" or k is "species" or k is "subspecies"
          htmlRow += "\n\t\t<td id='#{k}-#{i}' class='#{k} #{colClass}'>#{col}</td>"
        l++
        if l is Object.size(row)
          htmlRow += "\n\t\t<td id='#{k}-#{i}' class='edit-taxon #{colClass} text-center'><paper-icon-button icon='image:edit' class='edit' data-taxon='#{taxonQuery}'></paper-icon-button></td>"
          htmlRow += "\n\t</tr>"
          html += htmlRow
      if toInt(i) is targetCount
        html = htmlHead + html + htmlClose
        $(containerSelector).html(html)
        console.log("Processed #{toInt(i)+1} rows")
        $(".edit").click ->
          taxon = $(this).attr('data-taxon')
          lookupEditorSpecies(taxon)
        stopLoad()
  .fail (result,status) ->
    console.error("There was an error performing the search")
    console.warn(result,error,result.statusText)
    error = "#{result.status} - #{result.statusText}"
    $("#search-status").attr("text","Couldn't execute the search - #{error}")
    $("#search-status")[0].show()
    stopLoadError()

lookupEditorSpecies = (taxon = undefined) ->
  ###
  # Lookup a given species and load it for editing
  ###
  if not taxon?
    return false
  animateLoad()
  if not $("#modal-taxon-edit").exists()
    editHtml = "<paper-input label=\"Genus\" id=\"edit-genus\" name=\"edit-genus\" floatingLabel></paper-input> <paper-input label=\"Species\" id=\"edit-species\" name=\"edit-species\" floatingLabel></paper-input> <paper-input label=\"Subspecies\" id=\"edit-subspecies\" name=\"edit-subspecies\" floatingLabel></paper-input> <paper-input label=\"Common Name\" id=\"edit-common-name\" name=\"edit-common-name\" floatingLabel></paper-input> <paper-input label=\"Deprecated Scientific Names\" id=\"edit-deprecated-scientific\" name=\"edit-depreated-scientific\" floatingLabel aria-describedby=\"deprecatedHelp\"></paper-input> <span class=\"help-block\" id=\"deprecatedHelp\">List names here in the form <span class=\"code\">\"Genus species\":\"Authority: year\",\"Genus species\":\"Authority: year\",...</span></span> <paper-input label=\"Clade\" id=\"edit-major-type\" name=\"edit-major-type\" floatingLabel></paper-input> <paper-input label=\"Subtype\" id=\"edit-major-subtype\" name=\"edit-major-subtype\" floatingLabel></paper-input> <paper-input label=\"Minor clade / 'Family'\" id=\"edit-minor-type\" name=\"edit-minor-type\" floatingLabel></paper-input> <paper-input label=\"Linnean Order\" id=\"edit-linnean-order\" name=\"edit-linnean-order\" floatingLabel></paper-input> <paper-input label=\"Genus authority\" id=\"edit-genus-authority\" name=\"edit-genus-authority\" floatingLabel></paper-input> <paper-input label=\"Genus authority year\" id=\"edit-gauthyear\" name=\"edit-gauthyear\" floatingLabel></paper-input> <paper-input label=\"Species authority\" id=\"edit-species-authority\" name=\"edit-species-authority\" floatingLabel></paper-input> <paper-input label=\"Species authority year\" id=\"edit-sauthyear\" name=\"edit-sauthyear\" floatingLabel></paper-input> <paper-autogrow-textarea target=\"edit-notes\" id=\"edit-notes-autogrow\"> <textarea placeholder=\"Notes\" id=\"edit-notes\" name=\"edit-notes\"></textarea> </paper-autogrow-textarea> <paper-input label=\"Image\" id=\"edit-image\" name=\"edit-image\" floatingLabel aria-describedby=\"imagehelp\"></paper-input> <span class=\"help-block\" id=\"imagehelp\">The image path here should be relative to the <span class=\"code\">public_html/cndb/</span> directory.</span><input type='hidden' name='taxon-id' id='taxon-id'/>"
    html = "<paper-action-dialog backdrop layered closeSelector=\"[dismissive]\" id='modal-taxon-edit'><div id='modal-taxon-editor'>#{editHtml}</div><paper-button id='close-editor' dismissive>Cancel</paper-button><paper-button id='save-editor' affirmative>Save</paper-button></paper-action-dialog>"
    $("#search-results").after(html)
    # Bind the save button
    $("html /deep/ #save-editor")
    .click ->
      saveEditorEntry()
  # Look up the taxon, take the first result, and populate
  $.get(searchParams.targetApi,"q=#{taxon}","json")
  .done (result) ->
    try
      data = result.result[0]
      console.log("Populating from",data)
      $.each data, (col,d) ->
        # For each column, replace _ with - and prepend "edit"
        # This should be the selector
        if col is "id"
          $("#taxon-id").attr("value",d)
        if col is "authority_year"
          # Parse it out
          year = parseTaxonYear(d)
          $("#edit-gauthyear").attr("value",year.genus)
          $("#edit-sauthyear").attr("value",year.species)
        else
          fieldSelector = "#edit-#{col.replace(/_/g,"-")}"
          if col is "deprecated_scientific"
            d = JSON.stringify(d).slice(1,-1)
          if col isnt "notes"
            $(fieldSelector).attr("value",d)
          else
            $("html /deep/ #{fieldSelector}").text(d)
      $("#modal-taxon-edit")[0].open()
      stopLoad()
    catch e
      toastStatusMessage("Unable to populate the editor for this taxon - #{e.message}")
  .fail (result,status) ->
    toastStatusMessage("There was a server error populating this taxon. Please try again.")
  false

saveEditorEntry = ->
  ###
  # Send an editor state along with login credentials,
  # and report the save result back to the user
  ###
  # Make all the entries lowercase EXCEPT notes.
  # Close it on a successful save
  examineIds = [
    "genus"
    "species"
    "subspecies"
    "common-name"
    "major-type"
    "major-subtype"
    "minor-type"
    "linnean-order"
    "genus-authority"
    "species-authority"
    "notes"
    "image"
    ]
  saveObject = new Object()
  ## Manual parses
  try
    # Authority year
    gYear = $("html /deep/ #edit-gauthyear").val()
    sYear = $("html /deep/ #edit-sauthyear").val()
    auth = new Object()
    auth[gYear] = sYear
    authYearString = JSON.stringify(auth)
  catch e
    # Didn't work
    console.log("Failed to parase the authority year")
    authYearString = ""
  saveObject["authority_year"] = authYearString
  try
    dep = new Object()
    depS = $("#edit-deprecated-scientific").val()
    depA = depS.split(",")
    $.each depA, (k) ->
      item = k.split(":")
      dep[item[0]] = item[1]
    depString = JSON.stringify(dep)
  catch e
    console.log("Failed to parse the deprecated scientifics")
    depString = ""
  saveObject["deprecated_scientific"] = depString
  # For the rest of the items, iterate over and put on saveObject
  $.each examineIds, (k,id) ->
    console.log(k,id)
    thisSelector = "html /deep/ #edit-#{id}"
    col = id.replace(/-/g,"_")
    val = $(thisSelector).val()
    if col isnt "notes"
      val = val.toLowerCase()
    saveObject[col] = val
  saveObject["id"] = $("html /deep/ #taxon-id").val()
  saveString = JSON.stringify(saveObject)
  s64 = Base64.encodeURI(saveString)
  hash = $.cookie("ssarherps_auth")
  secret = $.cookie("ssarherps_secret")
  link = $.cookie("ssarherps_link")
  userVerification = "hash=#{hash}&secret=#{secret}&dblink=#{link}"
  args = "perform=save&#{userVerification}&data=#{s64}"
  console.log("Going to save",saveObject)
  animateLoad()
  $.post(adminParams.apiTarget,args,"json")
  .done (result) ->
    if result.status is true
      $("html /deep/ #modal-taxon-edit")[0].close()
      stopLoad()
      return false
    toastStatusMessage(result.human_error)
    console.error(result.error)
    return false
  .fail (result,status) ->
    toastStatusMessage("Failed to send the data to the server.")
    false

handleDragDropImage = ->
  ###
  # Take a drag-and-dropped image, and save it out to the database.
  # If we trigger this, we need to disable #edit-image
  ###
  foo()

foo = ->
  toastStatusMessage("Sorry, this feature is not yet finished")
  stopLoad()
  false

$ ->
  try
    checkAdmin()
    if adminParams.loadAdminUi is true
      loadAdminUi()
  catch e
    console.warn("This page does not have the criteria to check administration")

# Basic inits
root = exports ? this

uri = new Object()
uri.o = $.url()
uri.urlString = uri.o.attr('protocol') + '://' + uri.o.attr('host')  + uri.o.attr("directory")
uri.query = uri.o.attr("fragment")

window.locationData = new Object()
locationData.params =
  enableHighAccuracy: true
locationData.last = undefined

isBool = (str) -> str is true or str is false

isEmpty = (str) -> not str or str.length is 0

isBlank = (str) -> not str or /^\s*$/.test(str)

isNull = (str) ->
  try
    if isEmpty(str) or isBlank(str) or not str?
      unless str is false or str is 0 then return true
  catch
  false

isJson = (str) ->
  if typeof str is 'object' then return true
  try
    JSON.parse(str)
    return true
  catch
  false

isNumber = (n) -> not isNaN(parseFloat(n)) and isFinite(n)

toFloat = (str) ->
  if not isNumber(str) or isNull(str) then return 0
  parseFloat(str)

toInt = (str) ->
  if not isNumber(str) or isNull(str) then return 0
  parseInt(str)

`function toObject(arr) {
    var rv = {};
    for (var i = 0; i < arr.length; ++i)
        if (arr[i] !== undefined) rv[i] = arr[i];
    return rv;
}`

String::toBool = -> this.toString() is 'true'

Boolean::toBool = -> this.toString() is 'true' # In case lazily tested

Number::toBool = -> this is 1

Object.size = (obj) ->
  size = 0
  size++ for key of obj when obj.hasOwnProperty(key)
  size

delay = (ms,f) -> setTimeout(f,ms)

roundNumber = (number,digits = 0) ->
  multiple = 10 ** digits
  Math.round(number * multiple) / multiple

jQuery.fn.exists = -> jQuery(this).length > 0

jQuery.fn.polymerSelected = (setSelected = undefined) ->
  # See
  # https://www.polymer-project.org/docs/elements/paper-elements.html#paper-dropdown-menu
  if setSelected?
    if not isBool(setSelected)
      try
        childDropdown = $(this).find("[valueattr]")
        if isNull(childDropdown)
          childDropdown = $(this)
        prop = childDropdown.attr("valueattr")
        # Find the element where the prop matches the selected
        item = $(this).find("[#{prop}=#{setSelected}]")
        index = item.index()
        item.parent().prop("selected",index)
      catch e
        return false
    else
      console.log("setSelected #{setSelected} is boolean")
      $(this).parent().children().removeAttribute("selected")
      $(this).parent().children().removeAttribute("active")
      $(this).parent().children().removeClass("core-selected")
      $(this).prop("selected",setSelected)
      $(this).prop("active",setSelected)
      if setSelected is true
        $(this).addClass("core-selected")
  else
    val = undefined
    try
      childDropdown = $(this).find("[valueattr]")
      if isNull(childDropdown)
        childDropdown = $(this)
      prop = childDropdown.attr("valueattr")
      val = $(this).find(".core-selected").attr(prop)
    catch e
      return false
    if val is "null" or not val?
      val = undefined
    val

jQuery.fn.polymerChecked = (setChecked = undefined) ->
  # See
  # https://www.polymer-project.org/docs/elements/paper-elements.html#paper-dropdown-menu
  if setChecked?
    jQuery(this).prop("checked",setChecked)
  else
    val = jQuery(this)[0].checked
    if val is "null" or not val?
      val = undefined
    val

jQuery.fn.isVisible = ->
  jQuery(this).css("display") isnt "none"

jQuery.fn.hasChildren = ->
  Object.size(jQuery(this).children()) > 3

byteCount = (s) => encodeURI(s).split(/%..|./).length - 1

`function shuffle(o) { //v1.0
    for (var j, x, i = o.length; i; j = Math.floor(Math.random() * i), x = o[--i], o[i] = o[j], o[j] = x);
    return o;
}`

randomInt = (lower = 0, upper = 1) ->
  start = Math.random()
  if not lower?
    [lower, upper] = [0, lower]
  if lower > upper
    [lower, upper] = [upper, lower]
  return Math.floor(start * (upper - lower + 1) + lower)


window.debounce_timer = null
debounce: (func, threshold = 300, execAsap = false) ->
  # Borrowed from http://coffeescriptcookbook.com/chapters/functions/debounce
  # Only run the prototyped function once per interval.
  (args...) ->
    obj = this
    delayed = ->
      func.apply(obj, args) unless execAsap
    if window.debounce_timer?
      clearTimeout(window.debounce_timer)
    else if (execAsap)
      func.apply(obj, args)
    window.debounce_timer = setTimeout(delayed, threshold)

Function::debounce = (threshold = 300, execAsap = false, timeout = window.debounce_timer, args...) ->
  # Borrowed from http://coffeescriptcookbook.com/chapters/functions/debounce
  # Only run the prototyped function once per interval.
  func = this
  delayed = ->
    func.apply(func, args) unless execAsap
    console.log("Debounce applied")
  if timeout?
    try
      clearTimeout(timeout)
    catch e
      # just do nothing
  else if execAsap
    func.apply(obj, args)
    console.log("Executed immediately")
  window.debounce_timer = setTimeout(delayed, threshold)

mapNewWindows = ->
  # Do new windows
  $(".newwindow").each ->
    # Add a click and keypress listener to
    # open links with this class in a new window
    curHref = $(this).attr("href")
    if not curHref?
      # Support non-standard elements
      curHref = $(this).attr("data-href")
    openInNewWindow = (url) ->
      if not url? then return false
      window.open(url)
      return false
    $(this).click ->
      openInNewWindow(curHref)
    $(this).keypress ->
      openInNewWindow(curHref)

# Animations

toastStatusMessage = (message, className = "", duration = 3000, selector = "#search-status") ->
  ###
  # Pop up a status message
  ###
  if not isNumber(duration)
    duration = 3000
  if selector.slice(0,1) is not "#"
    selector = "##{selector}"
  if not $(selector).exists()
    html = "<paper-toast id=\"#{selector.slice(1)}\" duration=\"#{duration}\"></paper-toast>"
    $(html).appendTo("body")
  $(selector).attr("text",message)
  $(selector).addClass(className)
  $(selector)[0].show()
  delay duration + 500, ->
    # A short time after it hides, clean it up
    $(selector).empty()
    $(selector).removeClass(className)
    $(selector).attr("text","")


openLink = (url) ->
  if not url? then return false
  window.open(url)
  false

openTab = (url) ->
  openLink(url)

goTo = (url) ->
  if not url? then return false
  window.location.href = url
  false

animateLoad = (d = 50,elId = "loader") ->
  if elId.slice(0,1) is "#"
    selector = elId
    elId = elId.slice(1)
  else
    selector = "##{elId}"
  try
    if not $(selector).exists()
      $("body").append("<paper-spinner id=\"#{elId}\" active></paper-spinner")
    else
      $(selector).attr("active",true)
    false
  catch e
    console.log('Could not animate loader', e.message);

stopLoad = (elId="loader") ->
  if elId.slice(0,1) is "#"
    selector = elId
    elId = elId.slice(1)
  else
    selector = "##{elId}"
  try
    if $(selector).exists()
      $(selector).addClass("good")
      delay 1000, ->
        $(selector).removeClass("good")
        $(selector).attr("active",false)
  catch e
    console.log('Could not stop load animation', e.message);


stopLoadError = (elId="loader") ->
  if elId.slice(0,1) is "#"
    selector = elId
    elId = elId.slice(1)
  else
    selector = "##{elId}"
  try
    if $(selector).exists()
      $(selector).addClass("bad")
      delay 3000, ->
        $(selector).removeClass("bad")
        $(selector).attr("active",false)
  catch e
    console.log('Could not stop load error animation', e.message);

lightboxImages = (selector = ".lightboximage") ->
  options =
      onStart: ->
        overlayOn()
      onEnd: ->
        overlayOff()
        activityIndicatorOff()
      onLoadStart: ->
        activityIndicatorOn()
      onLoadEnd: ->
        activityIndicatorOff()
      allowedTypes: 'png|jpg|jpeg|gif'
  ###
  $(selector).has("img").each ->
    if not $(this).attr("nolightbox")?
      $(this).imageLightbox(options)
  ###
  # Until these narrower selectors work, let's use this
  $(selector).imageLightbox(options)

activityIndicatorOn = ->
  $('<div id="imagelightbox-loading"><div></div></div>' ).appendTo('body')
activityIndicatorOff = ->
  $('#imagelightbox-loading').remove()
overlayOn = ->
  $('<div id="imagelightbox-overlay"></div>').appendTo('body')
overlayOff = ->
  $('#imagelightbox-overlay').remove()

formatScientificNames = (selector = ".sciname") ->
    $(".sciname").each ->
      # Is it italic?
      nameStyle = if $(this).css("font-style") is "italic" then "normal" else "italic"
      $(this).css("font-style",nameStyle)

prepURI = (string) ->
  string = encodeURIComponent(string)
  string.replace(/%20/g,"+")


getLocation = (callback = undefined) ->
  geoSuccess = (pos,callback) ->
    window.locationData.lat = pos.coords.latitude
    window.locationData.lng = pos.coords.longitude
    window.locationData.acc = pos.coords.accuracy
    window.locationData.last = Date.now() # ms, unix time
    if callback?
      callback(window.locationData)
    false
  geoFail = (error,callback) ->
    locationError = switch error.code
      when 0 then "There was an error while retrieving your location: #{error.message}"
      when 1 then "The user prevented this page from retrieving a location"
      when 2 then "The browser was unable to determine your location: #{error.message}"
      when 3 then "The browser timed out retrieving your location."
    console.error(locationError)
    if callback?
      callback(false)
    false
  if navigator.geolocation
    navigator.geolocation.getCurrentPosition(geoSuccess,geoFail,window.locationData.params)
  else
    console.warn("This browser doesn't support geolocation!")
    if callback?
      callback(false)

bindClickTargets = ->
  $(".click")
  .unbind()
  .click ->
    openTab($(this).attr("data-url"))
  

$ ->
  bindClickTargets()
  try
    $('[data-toggle="tooltip"]').tooltip()
  catch e
    console.warn("Tooltips were attempted to be set up, but do not exist")
  getLocation()

searchParams = new Object()
searchParams.targetApi = "commonnames_api.php"
searchParams.targetContainer = "#result_container"
searchParams.apiPath = uri.urlString + searchParams.targetApi

performSearch = (stateArgs = undefined) ->
  ###
  # Check the fields and filters and do the async search
  ###
  if not stateArgs?
    # No arguments have been passed in
    s = $("#search").val()
    # Store a version before we do any search modifiers
    sOrig = s
    s = s.toLowerCase()
    filters = getFilters()
    if (isNull(s) or not s?) and isNull(filters)
      $("#search-status").attr("text","Please enter a search term.")
      $("#search-status")[0].show()
      return false
    $("#search").blur()
    # Remove periods from the search
    s = s.replace(/\./g,"")
    s = prepURI(s)
    if $("#loose").polymerChecked()
      s = "#{s}&loose=true"
    if $("#fuzzy").polymerChecked()
      s = "#{s}&fuzzy=true"
    # Add on the filters
    if not isNull(filters)
      console.log("Got filters - #{filters}")
      s = "#{s}&filter=#{filters}"
    args = "q=#{s}"
  else
    # An argument has been passed in
    if stateArgs is true
      # Special case -- do a search on everything
      args = "q="
      sOrig = "(all items)"
    else
      # Do the search exactly as passed. The fragment should ALREADY
      # be decoded at this point.
      args = "q=#{stateArgs}"
      sOrig = stateArgs.split("&")[0]
    console.log("Searching on #{stateArgs}")
  if s is "#" or (isNull(s) and isNull(args)) or (args is "q=" and stateArgs isnt true)
    return false
  animateLoad()
  console.log("Got search value #{s}, hitting","#{searchParams.apiPath}?#{args}")
  $.get(searchParams.targetApi,args,"json")
  .done (result) ->
    # Populate the result container
    console.log("Search executed by #{result.method} with #{result.count} results.")
    if toInt(result.count) is 0
      if result.status is true
        if result.query_params.filter.had_filter is true
          filterText = ""
          i = 0
          $.each result.query_params.filter.filter_params, (col,val) ->
            if col isnt "BOOLEAN_TYPE"
              if i isnt 0
                filterText = "#{filter_text} #{result.filter.filter_params.BOOLEAN_TYPE}"
              filterText = "#{filterText} #{col.replace(/_/g," ")} is #{val}"
          text = "\"#{sOrig}\" where #{filterText} returned no results."
        else
          text = "\"#{sOrig}\" returned no results."
      else
        text = result.human_error
      $("#search-status").attr("text",text)
      $("#search-status")[0].show()
      stopLoadError()
      return false
    if result.status is true
      formatSearchResults(result)
      return false
    $("#search-status").attr("text",result.human_error)
    $("#search-status")[0].show()
    console.error(result.error)
    console.warn(result)
    stopLoadError()
  .fail (result,error) ->
    console.error("There was an error performing the search")
    console.warn(result,error,result.statusText)
    error = "#{result.status} - #{result.statusText}"
    $("#search-status").attr("text","Couldn't execute the search - #{error}")
    $("#search-status")[0].show()
    stopLoadError()
  .always ->
    # Anything we always want done
    b64s = Base64.encodeURI(s)
    if s? then setHistory("#{uri.urlString}##{b64s}")
    false

getFilters = (selector = ".cndb-filter",booleanType = "AND") ->
  ###
  # Look at $(selector) and apply the filters as per
  # https://github.com/tigerhawkvok/SSAR-species-database#search-flags
  # It's meant to work with Polymer dropdowns, but it'll fall back to <select><option>
  ###
  filterList = new Object()
  $(selector).each ->
    col = $(this).attr("data-column")
    if not col?
      # Skip this iteration
      return true
    val = $(this).polymerSelected()
    if val is "any" or val is "all" or val is "*"
      # Wildcard filter -- just don't give anything
      # Go to the next iteration
      return true
    if isNull(val) or val is false
      val = $(this).val()
      if isNull(val)
        # Skip this iteration
        return true
      else
    filterList[col] = val.toLowerCase()
  if Object.size(filterList) is 0
    # Pass back an empty string
    console.log("Got back an empty filter list.")
    return ""
  try
    filterList["BOOLEAN_TYPE"] = booleanType
    jsonString = JSON.stringify(filterList)
    encodedFilter = Base64.encodeURI(jsonString)
    console.log("Returning #{encodedFilter} from",filterList)
    return encodedFilter
  catch e
    return false


formatSearchResults = (result,container = searchParams.targetContainer) ->
  data = result.result
  searchParams.result = data
  headers = new Array()
  html = ""
  htmlHead = "<table id='cndb-result-list' class='table table-striped table-hover'>\n\t<tr class='cndb-row-headers'>"
  htmlClose = "</table>"
  # We start at 0, so we want to count one below
  targetCount = toInt(result.count)-1
  colClass = null
  bootstrapColCount = 0
  $.each data, (i,row) ->
    if toInt(i) is 0
      j = 0
      htmlHead += "\n<!-- Table Headers - #{Object.size(row)} entries -->"
      $.each row, (k,v) ->
        niceKey = k.replace(/_/g," ")
        if k isnt "id"  and k isnt "minor_type" and k isnt "notes" #and niceKey isnt "image"
          if $("#show-deprecated").polymerSelected() isnt true
            alt = "deprecated_scientific"
          else
            # Empty placeholder
            alt = ""
          if k isnt alt
            htmlHead += "\n\t\t<th class='text-center'>#{niceKey}</th>"
            bootstrapColCount++
        j++
        if j is Object.size(row)
          htmlHead += "\n\t</tr>"
          htmlHead += "\n<!-- End Table Headers -->"
          console.log("Got #{bootstrapColCount} display columns.")
          bootstrapColSize = roundNumber(12/bootstrapColCount,0)
          colClass = "col-md-#{bootstrapColSize}"
    taxonQuery = "#{row.genus}+#{row.species}"
    if not isNull(row.subspecies)
      taxonQuery = "#{taxonQuery}+#{row.subspecies}"
    htmlRow = "\n\t<tr id='cndb-row#{i}' class='cndb-result-entry' data-taxon=\"#{taxonQuery}\">"
    l = 0
    $.each row, (k,col) ->
      if k isnt "id" and k isnt "minor_type" and k isnt "notes"
        if k is "authority_year"
          try
            try
              d = JSON.parse(col)
            catch e
              # attempt to fix it
              console.warn("There was an error parsing '#{col}', attempting to fix - ",e.message)
              split = col.split(":")
              year = split[1].slice(split[1].search("\"")+1,-2)
              console.log("Examining #{year}")
              year = year.replace(/"/g,"'")
              split[1] = "\"#{year}\"}"
              col = split.join(":")
              console.log("Reconstructed #{col}")
              d = JSON.parse(col)
            genus = Object.keys(d)[0]
            species = d[genus]
            col = "G: #{genus}<br/>S: #{species}"
          catch e
            # Render as-is
            console.error("There was an error parsing '#{col}'",e.message)
            d = col
        if $("#show-deprecated").polymerSelected() isnt true
          alt = "deprecated_scientific"
        else
          # Empty placeholder
          alt = ""
        if k isnt alt
          if k is "image"
            # Set up the images
            if isNull(col)
              # Get a CalPhotos link as
              # http://calphotos.berkeley.edu/cgi/img_query?rel-taxon=contains&where-taxon=batrachoseps+attenuatus
              col = "<paper-icon-button icon='launch' data-href='http://calphotos.berkeley.edu/cgi/img_query?rel-taxon=contains&where-taxon=#{taxonQuery}' class='newwindow calphoto' data-taxon=\"#{taxonQuery}\"></paper-icon-button>"
            else
              col = "<paper-icon-button icon='image:image' data-lightbox='#{col}' class='lightboximage'></paper-icon-button>"
          # What should be centered, and what should be left-aligned?
          if k isnt "genus" and k isnt "species" and k isnt "subspecies"
            kClass = "#{k} text-center"
          else
            # Left-aligned
            kClass = k
          htmlRow += "\n\t\t<td id='#{k}-#{i}' class='#{kClass} #{colClass}'>#{col}</td>"
      l++
      if l is Object.size(row)
        htmlRow += "\n\t</tr>"
        html += htmlRow
    # Check if we're done
    if toInt(i) is targetCount
      html = htmlHead + html + htmlClose
      console.log("Processed #{toInt(i)+1} rows")
      $(container).html(html)
      mapNewWindows()
      lightboxImages()
      modalTaxon()
      $("#result-count").text(" - #{result.count} entries")
      stopLoad()
      # Lazy-replace linkout calphotos with images. Each one needs a hit!
      # deferCalPhotos()

parseTaxonYear = (taxonYearString,strict = true) ->
  try
    d = JSON.parse(taxonYearString)
  catch e
    # attempt to fix it
    console.warn("There was an error parsing '#{taxonYearString}', attempting to fix - ",e.message)
    split = taxonYearString.split(":")
    year = split[1].slice(split[1].search("\"")+1,-2)
    console.log("Examining #{year}")
    year = year.replace(/"/g,"'")
    split[1] = "\"#{year}\"}"
    taxonYearString = split.join(":")
    console.log("Reconstructed #{taxonYearString}")
    try
      d = JSON.parse(taxonYearString)
    catch e
      if strict
        return false
      else
        return taxonYearString
  genus = Object.keys(d)[0]
  species = d[genus]
  year = new Object()
  year.genus = genus
  year.species = species
  return year

checkTaxonNear = (taxonQuery = undefined, callback = undefined, selector = "html /deep/ #near-me-container") ->
  ###
  # Check the iNaturalist API to see if the taxon is in your county
  # See https://github.com/tigerhawkvok/SSAR-species-database/issues/7
  ###
  if not taxonQuery?
    console.warn("Please specify a taxon.")
    return false;
  if not locationData.last?
    getLocation()
  elapsed = (Date.now() - locationData.last)/1000
  if elapsed > 15*60 # 15 minutes
    getLocation()
  # Now actually check
  apiUrl = "http://www.inaturalist.org/places.json"
  args = "taxon=#{taxonQuery}&latitude=#{locationData.lat}&longitude=#{locationData.lng}&place_type=county"
  geoIcon = ""
  cssClass = ""
  tooltipHint = ""
  $.get(apiUrl,args,"json")
  .done (result) ->
    if Object.size(result) > 0
      geoIcon = "communication:location-on"
      cssClass = "good-location"
      tooltipHint = "This species occurs in your county"
    else
      geoIcon = "communication:location-off"
      cssClass = "bad-location"
      tooltipHint = "This species does not occur in your county"
  .fail (result,status) ->
    cssClass = "bad-location"
    geoIcon = "warning"
    tooltipHint = "We couldn't determine your location"
  .always ->
    $(selector).html("<core-icon icon='#{geoIcon}' class='small-icon #{cssClass}' data-toggle='tooltip' id='near-me-icon'></core-icon>")
    $("html /deep/ #near-me-icon").attr("title",tooltipHint)
    $("html /deep/ #near-me-icon").tooltip()
    if callback?
      callback()
  false

  

deferCalPhotos = (selector = ".calphoto") ->
  ###
  # Defer renders of calphoto linkouts
  # Hit targets of form
  # http://calphotos.berkeley.edu/cgi-bin/img_query?getthumbinfo=1&num=all&taxon=Acris+crepitans&format=xml
  ###
  count = $(selector).length
  cpUrl = "http://calphotos.berkeley.edu/cgi-bin/img_query"
  i = 0
  $(selector).each ->
    i++
    thisLinkout = $(this)
    taxon = thisLinkout.attr("data-taxon")
    args = "getthumbinfo=1&num=all&cconly=1&taxon=#{taxon}&format=xml"
    $.get(cpUrl,args)
    .done (resultXml) ->
      result = xmlToJSON.parseString(resultXml)
      data = result.xml.calphotos
      thumb = data.thumb_url
      large = data.enlarge_jpeg_url
      link = data.enlarge_url
      # Render a thumbnail that onclick will lightbox
      html = "<a href='#{large}' class='calphoto-img-anchor'><img src='#{thumb}' data-href='#{link}' class='calphoto-img-thumb' data-taxon='#{taxon}'/></a>"
      thisLinkout.replaceWith(html)
      false
    .fail (result,status) ->
      false
    .always ->
      if i is count
        lightboxImages(".calphoto-image-anchor")
  false

modalTaxon = (taxon = undefined) ->
  if not taxon?
    $(".cndb-result-entry").click ->
      modalTaxon($(this).attr("data-taxon"))
    return false
  # Pop open a paper action dialog ...
  # https://www.polymer-project.org/docs/elements/paper-elements.html#paper-action-dialog
  animateLoad()
  if not $("#modal-taxon").exists()
    html = "<paper-action-dialog backdrop layered closeSelector=\"[affirmative]\" id='modal-taxon'><div id='modal-taxon-content'></div><paper-button dismissive id='modal-inat-linkout'>iNaturalist</paper-button><paper-button dismissive id='modal-calphotos-linkout'>CalPhotos</paper-button><paper-button affirmative autofocus>Close</paper-button></paper-action-dialog>"
    $("#result_container").after(html)
  $.get(searchParams.targetApi,"q=#{taxon}","json")
  .done (result) ->
    data = result.result[0]
    console.log("Got",data)
    year = parseTaxonYear(data.authority_year)
    yearHtml = ""
    if year isnt false
      yearHtml = "<div id='near-me-container'></div><p><span class='genus'>#{data.genus}</span>, <span class='genus_authority'>#{data.genus_authority}</span> #{year.genus}; <span class='species'>#{data.species}</span>, <span class='species_authority'>#{data.species_authority}</span> #{year.species}</p>"
    deprecatedHtml = ""
    if not isNull(data.deprecated_scientific)
      deprecatedHtml = "<p>Deprecated names:"
      try
        sn = JSON.parse(data.deprecated_scientific)
        i = 0
        $.each sn, (scientific,authority) ->
          i++
          if i isnt 1
            deprecatedHtml += "; "
          deprecatedHtml += "<span class='sciname'>#{scientific}</span>, #{authority}"
          if i is Object.size(sn)
            deprecatedHtml += "</p>"
      catch e
        # skip it
        deprecatedHtml = ""
        console.error("There were deprecated scientific names, but the JSON was malformed.")
    minorTypeHtml = ""
    if not isNull(data.minor_type)
      minorTypeHtml = " <core-icon icon='arrow-forward'></core-icon> <span id='taxon-minor-type'>#{data.minor_type}</span>"
    # Populate the taxon
    if isNull(data.notes)
      data.notes = "Sorry, we have no notes on this taxon yet."
    html = "<div id='meta-taxon-info'>#{yearHtml}<p>Common name: <span id='taxon-common-name' class='common_name'>#{data.common_name}</span></p><p>Type: <span id='taxon-type'>#{data.major_type}</span> (<span id='taxon-common-type'>#{data.major_common_type}</span>) <core-icon icon='arrow-forward'></core-icon> <span id='taxon-subtype'>#{data.major_subtype}</span>#{minorTypeHtml}</p>#{deprecatedHtml}</div><h3>Taxon Notes</h3><p id='taxon-notes'>#{data.notes}</p>"
    $("#modal-taxon-content").html(html)
    $("#modal-inat-linkout")
    .unbind()
    .click ->
      openTab("http://www.inaturalist.org/taxa/search?q=#{taxon}")
    $("#modal-calphotos-linkout")
    .unbind()
    .click ->
      openTab("http://calphotos.berkeley.edu/cgi/img_query?rel-taxon=contains&where-taxon=#{taxon}")
    formatScientificNames()
    # Set the heading
    humanTaxon = taxon.charAt(0).toUpperCase()+taxon.slice(1)
    humanTaxon = humanTaxon.replace(/\+/g," ")
    $("#modal-taxon").attr("heading",humanTaxon)
    # Open it
    stopLoad()
    checkTaxonNear taxon, ->
      $("#modal-taxon")[0].open()
  .fail (result,status) ->
    stopLoadError()
  false

sortResults = (by_column) ->
  # Somethign clever -- look at each of the by_column points, then
  # throw those into an array and sort those, using their index as a
  # map to data and re-mapping data by those orders. May need to use
  # the index of a duplicated array as the reference - walk through
  # sorted and lookup position in reference, then data[index] = data[ref_pos]
  data = searchParams.result

setHistory = (url = "#",state = null, title = null) ->
  ###
  # Set up the history to provide something linkable
  ###
  history.pushState(state,title,url)
  # Rewrite the query URL
  uri.query = $.url(url).attr("fragment")
  false

$ ->
  # Do bindings
  console.log("Doing onloads ...")
  animateLoad()
  # Set up popstate
  window.addEventListener "popstate", (e) ->
    uri.query = $.url().attr("fragment")
    loadArgs = Base64.decode(uri.query)
    console.log("Popping state to #{loadArgs}")
    performSearch(loadArgs)
    temp = loadArgs.split("&")[0]
    $("#search").attr("value",temp)
  ## Set events
  $("#search_form").submit (e) ->
    e.preventDefault()
    performSearch()
  $("#collapse-advanced").on "shown.bs.collapse", ->
    $("#collapse-icon").attr("icon","unfold-less")
  $("#collapse-advanced").on "hidden.bs.collapse", ->
    $("#collapse-icon").attr("icon","unfold-more")
  # Bind enter keydown
  $("#search_form").keypress (e) ->
    if e.which is 13 then performSearch()
  # Bind clicks
  $("#do-search").click ->
    performSearch()
  $("#do-search-all").click ->
    performSearch(true)
  # Do a fill of the result container
  if isNull uri.query
    loadArgs = ""
  else
    try
      loadArgs = Base64.decode(uri.query)
      queryUrl = $.url("#{searchParams.apiPath}?q=#{loadArgs}")
      try
        looseState = queryUrl.param("loose").toBool()
      catch e
        looseState = false
      try
        fuzzyState = queryUrl.param("fuzzy").toBool()
      catch e
        fuzzyState = false
      $("#loose").prop("checked",looseState)
      $("#fuzzy").prop("checked",fuzzyState)
      temp = loadArgs.split("&")[0]
      # Remove any plus signs in the query
      temp = temp.replace(/\+/," ")
      $("#search").attr("value",temp)
      # Filters
      try
        f64 = queryUrl.param("filter")
        filterObj = JSON.parse(Base64.decode(f64))
        openFilters = false
        $.each filterObj, (col,val) ->
          col = col.replace(/_/g,"-")
          selector = "##{col}-filter"
          if col isnt "type"
            $(selector).attr("value",val)
            openFilters = true
          else
            $("#linnean-order").polymerSelected(val)
        if openFilters
          # Open up #collapse-advanced
          $("#collapse-advanced").collapse("show")
      catch e
        # Do nothing
        f64 = false
    catch e
      console.error("Bad argument #{uri.query} => #{loadArgs}, looseState, fuzzyState",looseState,fuzzyState,"#{searchParams.apiPath}?q=#{loadArgs}")
      console.warn(e.message)
      loadArgs = ""
  # Perform the initial search
  if not isNull(loadArgs) and loadArgs isnt "#"
    console.log("Doing initial search with '#{loadArgs}', hitting","#{searchParams.apiPath}?q=#{loadArgs}")
    $.get(searchParams.targetApi,"q=#{loadArgs}","json")
    .done (result) ->
      # Populate the result container
      if result.status is true and result.count > 0
        console.log("Got a valid result, formatting #{result.count} results.")
        formatSearchResults(result)
        return false
      if result.count is 0
        result.human_error = "No results for \"#{loadArgs.split("&")[0]}\""
      $("#search-status").attr("text",result.human_error)
      $("#search-status")[0].show()
      console.error(result.error)
      console.warn(result)
      stopLoadError()
    .fail (result,error) ->
      console.error("There was an error loading the generic table")
      console.warn(result,error,result.statusText)
      error = "#{result.status} - #{result.statusText}"
      $("#search-status").attr("text","Couldn't load table - #{error}")
      $("#search-status")[0].show()
      stopLoadError()
    .always ->
      # Anything we always want done
      $("#search").attr("disabled",false)
      false
  else
    stopLoad()
    $("#search").attr("disabled",false)
    $("#loose").prop("checked",true)