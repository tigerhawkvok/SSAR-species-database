searchParams = new Object()
searchParams.targetApi = "commonnames_api.php"
searchParams.targetContainer = "#result_container"
searchParams.apiPath = uri.urlString + searchParams.targetApi

ssar = new Object()
# Base query URLs for out-of-site linkouts
ssar.affiliateQueryUrl =
  # As of 2015.05.24, no SSL connection
  amphibiaWeb: "http://amphibiaweb.org/cgi/amphib_query"
  # As of 2015.05.24, no SSL connection
  reptileDatabase: "http://reptile-database.reptarium.cz/species"
  # As of 2015.05.24, no SSL connection
  calPhotos: "http://calphotos.berkeley.edu/cgi/img_query"
  # As of 2015.05.24, the SSL cert is only for www.inaturalist.org
  iNaturalist: "https://www.inaturalist.org/taxa/search"


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
      clearSearch(true)
      $("#search-status").attr("text",text)
      $("#search-status")[0].show()
      stopLoadError()
      return false
    if result.status is true
      formatSearchResults(result)
      return false
    clearSearch(true)
    $("#search-status").attr("text",result.human_error)
    $("#search-status")[0].show()
    console.error(result.error)
    console.warn(result)
    stopLoadError()
  .fail (result,error) ->
    console.error("There was an error performing the search")
    console.warn(result,error,result.statusText)
    error = "#{result.status} - #{result.statusText}"
    # It probably doesn't make sense to clear the search on a bad
    # server call ...
    # clearSearch(true)
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
    # console.log("Got back an empty filter list.")
    return ""
  try
    filterList["BOOLEAN_TYPE"] = booleanType
    jsonString = JSON.stringify(filterList)
    encodedFilter = Base64.encodeURI(jsonString)
    # console.log("Returning #{encodedFilter} from",filterList)
    return encodedFilter
  catch e
    return false


formatSearchResults = (result,container = searchParams.targetContainer) ->
  ###
  # Take a result object from the server's lookup, and format it to
  # display search results.
  # See
  # http://ssarherps.org/cndb/commonnames_api.php?q=batrachoseps+attenuatus&loose=true
  # for a sample search result return.
  ###
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
  dontShowColumns = [
    "id"
    "minor_type"
    "notes"
    "major_type"
    "taxon_author"
    "taxon_credit"
    "image_license"
    "image_credit"
    ]
  $.each data, (i,row) ->
    if toInt(i) is 0
      j = 0
      htmlHead += "\n<!-- Table Headers - #{Object.size(row)} entries -->"
      $.each row, (k,v) ->
        niceKey = k.replace(/_/g," ")
        unless k in dontShowColumns
          # or niceKey is "image" ...
          if $("#show-deprecated").polymerSelected() isnt true
            alt = "deprecated_scientific"
          else
            # Empty placeholder
            alt = ""
          if k isnt alt
            # Remap names that were changed late into dev
            # See
            # https://github.com/tigerhawkvok/SSAR-species-database/issues/19
            # as an example
            niceKey = switch niceKey
              when "common name" then "english name"
              when "major subtype" then "english subtype"
              else niceKey
            htmlHead += "\n\t\t<th class='text-center'>#{niceKey}</th>"
            bootstrapColCount++
        j++
        if j is Object.size(row)
          htmlHead += "\n\t</tr>"
          htmlHead += "\n<!-- End Table Headers -->"
          # console.log("Got #{bootstrapColCount} display columns.")
          bootstrapColSize = roundNumber(12/bootstrapColCount,0)
          colClass = "col-md-#{bootstrapColSize}"
    taxonQuery = "#{row.genus}+#{row.species}"
    if not isNull(row.subspecies)
      taxonQuery = "#{taxonQuery}+#{row.subspecies}"
    htmlRow = "\n\t<tr id='cndb-row#{i}' class='cndb-result-entry' data-taxon=\"#{taxonQuery}\">"
    l = 0
    $.each row, (k,col) ->
      unless k in dontShowColumns
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
              col = "<paper-icon-button icon='launch' data-href='#{ssar.affiliateQueryUrl.calPhotos}?rel-taxon=contains&where-taxon=#{taxonQuery}' class='newwindow calphoto click' data-taxon=\"#{taxonQuery}\"></paper-icon-button>"
            else
              col = "<paper-icon-button icon='image:image' data-lightbox='#{uri.urlString}#{col}' class='lightboximage'></paper-icon-button>"
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
      # console.log("Processed #{toInt(i)+1} rows")
      $(container).html(html)
      mapNewWindows()
      lightboxImages()
      modalTaxon()
      $("#result-count").text(" - #{result.count} entries")
      stopLoad()



parseTaxonYear = (taxonYearString,strict = true) ->
  ###
  # Take the (theoretically nicely JSON-encoded) taxon year/authority
  # string and turn it into a canonical object for the modal dialog to use
  ###
  try
    d = JSON.parse(taxonYearString)
  catch e
    # attempt to fix it
    console.warn("There was an error parsing '#{taxonYearString}', attempting to fix - ",e.message)
    split = taxonYearString.split(":")
    year = split[1].slice(split[1].search('"')+1,-2)
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

checkTaxonNear = (taxonQuery = undefined, callback = undefined, selector = "#near-me-container") ->
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
    tooltipHtml = """
    <div class="tooltip fade top in right" role="tooltip" style="top: 6.5em; left: 4em; right:initial; display:none" id="manual-location-tooltip">
      <div class="tooltip-arrow" style="top:50%;left:5px"></div>
      <div class="tooltip-inner">#{tooltipHint}</div>
    </div>
    """
    try
      $("html /deep/ #{selector}").html("<core-icon icon='#{geoIcon}' class='small-icon #{cssClass} near-me' data-toggle='tooltip' id='near-me-icon'></core-icon>")
      $("html /deep/ #near-me-container")
      .after(tooltipHtml)
      .mouseenter ->
        $("html /deep/ #manual-location-tooltip").css("display","block")
        false
      .mouseleave ->
        $("html /deep/ #manual-location-tooltip").css("display","none")
        false
      #$("html /deep/ .near-me").tooltip()
    catch e
      $("html >>> #{selector}").html("<core-icon icon='#{geoIcon}' class='small-icon #{cssClass} near-me' data-toggle='tooltip' id='near-me-icon'></core-icon>")
      $("html >>> #near-me-container")
      .after(tooltipHtml)
      .mouseenter ->
        $("html >>> #manual-location-tooltip").css("display","block")
        false
      .mouseleave ->
        $("html >>> #manual-location-tooltip").css("display","none")
        false
      #$("html >>> .near-me").tooltip()
      try
        # Attempt to do this without looking through the shadow DOM
        $(selector).html("<core-icon icon='#{geoIcon}' class='small-icon #{cssClass}' data-toggle='tooltip' id='near-me-icon'></core-icon>")
        $("#near-me-container")
        .after(tooltipHtml)
        .mouseenter ->
          $("#manual-location-tooltip").css("display","block")
          false
        .mouseleave ->
          $("#manual-location-tooltip").css("display","none")
          false
        #$(".near-me").tooltip()
      catch e
        console.warn("Fallback failed to draw contents on the <paper-action-dialog>")
    if callback?
      callback()
  false



insertModalImage = (imageObject = ssar.taxonImage, taxon = ssar.activeTaxon, callback = undefined) ->
  ###
  # Insert into the taxon modal a lightboxable photo. If none exists,
  # load from CalPhotos
  #
  # CalPhotos functionality blocked on
  # https://github.com/tigerhawkvok/SSAR-species-database/issues/30
  ###
  # Is the modal dialog open?
  unless taxon?
    console.error("Tried to insert a modal image, but no taxon was provided!")
    return false
  unless typeof taxon is "object"
    console.error("Invalid taxon data type (expecting object), got #{typeof taxon}")
    warnArgs =
      taxon: taxon
      imageUrl: imageUrl
      defaultTaxon: ssar.activeTaxon
      defaultImage: ssar.taxonImage
    console.warn(warnArgs)
    return false
  # Image insertion helper
  insertImage = (image, taxonQueryString, classPrefix = "calphoto") ->
    ###
    # Insert a lightboxed image into the modal taxon dialog. This must
    # be shadow-piercing, since the modal dialog is a
    # paper-action-dialog.
    #
    # @param image an object with parameters [thumbUri, imageUri,
    #   imageLicense, imageCredit], and optionally imageLinkUri
    ###
    # Build individual args from object
    thumbnail = image.thumbUri
    largeImg = image.imageUri
    largeImgLink = image.imageLinkUri? image.imageUri
    imgLicense = image.imageLicense
    imgCredit = image.imageCredit
    html = """
    <div class="modal-img-container">
      <a href="#{largeImg}" class="#{classPrefix}-img-anchor center-block text-center">
        <img src="#{thumbnail}"
          data-href="#{largeImgLink}"
          class="#{classPrefix}-img-thumb"
          data-taxon="#{taxonQueryString}" />
      </a>
      <p class="small text-muted text-center">
        Image by #{imgCredit} under #{imgLicense}
      </p>
    </div>
    """
    d$("#meta-taxon-info").before(html)
    try
      # Call lightboxImages with the second argument "true" to do a
      # shadow-piercing lookup
      lightboxImages(".#{classPrefix}-img-anchor", true)
    catch e
      console.error("Error lightboxing images")
    if typeof callback is "function"
      callback()
    false
  # Now that that's out of the way, we actually check the information
  # and process it
  taxonArray = [taxon.genus,taxon.species]
  if taxon.subspecies?
    taxonArray.push(taxon.subspecies)
  taxonString = taxonArray.join("+")

  if imageObject.imageUri?
    # The image URI is valid, so insert it
    if typeof imageObject is "string"
      # Make it conform to expectations
      imageUrl = imageObject
      imageObject = new Object()
      imageObject.imageUri = imageUrl
    # Construct the thumb URI from the provided full-sized path
    imgArray = imageObject.imageUri.split(".")
    extension = imgArray.pop()
    # In case the uploaded file has "." in it's name, we want to re-join
    imgPath = imgArray.join(".")
    imageObject.thumbUri = "#{uri.urlString}#{imgPath}-thumb.#{extension}"
    imageObject.imageUri = "#{uri.urlString}#{imgPath}.#{extension}"
    # And finally, call our helper function
    insertImage(imageObject, taxonString, "ssarimg")
    return false
  ###
  # OK, we don't have it, do CalPhotos
  #
  # Hit targets of form
  # http://calphotos.berkeley.edu/cgi-bin/img_query?getthumbinfo=1&num=all&taxon=Acris+crepitans&format=xml
  #
  # See
  # http://calphotos.berkeley.edu/thumblink.html
  # for API reference.
  ###
  args = "getthumbinfo=1&num=all&cconly=1&taxon=#{taxonString}&format=xml"
  console.log("Looking at","#{ssar.affiliateQueryUrl.calPhotos}?#{args}")
  ## CalPhotos doesn't have good headers set up. Try a CORS request.
  # CORS success callback
  doneCORS = (resultXml) ->
    result = xmlToJSON.parseString(resultXml)
    data = result.xml.calphotos
    unless data?
      console.warn("CalPhotos didn't return any valid images for this search!")
      return false
    imageObject = new Object()
    imageObject.thumbUri = data.thumb_url
    unless thumb?
      console.warn("CalPhotos didn't return any valid images for this search!")
      return false
    imageObject.imageUri = data.enlarge_jpeg_url
    imageObject.imageLinkUri = data.enlarge_url
    imageObject.imageLicense = imageObject.license
    imageObject.imageCredit = "#{imageObject.copyright} (via CalPhotos)"
    # Do the image insertion via our helper function
    insertImage(imageObject,taxonSring)
    false
  # CORS failure callback
  failCORS = (result,status) ->
    console.error("Couldn't load a CalPhotos image to insert!")
    false
  # The actual call attempts.
  try
    doCORSget(ssar.affiliateQueryUrl.calPhotos, args, doneCORS, failCORS)
  catch e
    console.error(e.message)
  false


modalTaxon = (taxon = undefined) ->
  ###
  # Pop up the modal taxon dialog for a given species
  ###
  if not taxon?
    # If we have no taxon defined at all, bind all the result entries
    # from a search into popping one of these up
    $(".cndb-result-entry").click ->
      modalTaxon($(this).attr("data-taxon"))
    return false
  # Pop open a paper action dialog ...
  # https://www.polymer-project.org/docs/elements/paper-elements.html#paper-action-dialog
  animateLoad()
  if not $("#modal-taxon").exists()
    # On very small devices, for both real-estate and
    # optimization-related reasons, we'll hide calphotos and the alternate
    html = """
    <paper-action-dialog backdrop layered closeSelector="[affirmative]" id='modal-taxon'>
      <div id='modal-taxon-content'></div>
      <paper-button dismissive id='modal-inat-linkout'>iNaturalist</paper-button>
      <paper-button dismissive id='modal-calphotos-linkout' class="hidden-xs">CalPhotos</paper-button>
      <paper-button dismissive id='modal-alt-linkout' class="hidden-xs"></paper-button>
      <paper-button affirmative autofocus>Close</paper-button>
    </paper-action-dialog>
    """
    $("#result_container").after(html)
  $.get(searchParams.targetApi,"q=#{taxon}","json")
  .done (result) ->
    data = result.result[0]
    unless data?
      toastStatusMessage("There was an error fetching the entry details. Please try again later.")
      stopLoadError()
      return false
    # console.log("Got",data)
    year = parseTaxonYear(data.authority_year)
    yearHtml = ""
    if year isnt false
      yearHtml = "<div id='near-me-container' data-toggle='tooltip' data-placement='top' title='' class='near-me'></div><p><span class='genus'>#{data.genus}</span>, <span class='genus_authority'>#{data.genus_authority}</span> #{year.genus}; <span class='species'>#{data.species}</span>, <span class='species_authority'>#{data.species_authority}</span> #{year.species}</p>"
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
      data.taxon_credit = ""
    else
      if isNull(data.taxon_credit) or data.taxon_credit is "null"
        data.taxon_credit = "This taxon information is uncredited."
      else
        data.taxon_credit = "Taxon information by #{data.taxon_credit}."
    try
      notes = markdown.toHTML(data.notes)
    catch e
      notes = data.notes
      console.warn("Couldn't parse markdown!! #{e.message}")
    commonType = unless isNull(data.major_common_type) then " (<span id='taxon-common-type'>#{data.major_common_type}</span>) " else ""
    html = """
    <div id='meta-taxon-info'>
      #{yearHtml}
      <p>
        English name: <span id='taxon-common-name' class='common_name'>#{data.common_name}</span>
      </p>
      <p>
        Type: <span id='taxon-type' class="major_type">#{data.major_type}</span>
        #{commonType}
        <core-icon icon='arrow-forward'></core-icon>
        <span id='taxon-subtype' class="major_subtype">#{data.major_subtype}</span>#{minorTypeHtml}
      </p>
      #{deprecatedHtml}
    </div>
    <h3>Taxon Notes</h3>
    <p id='taxon-notes'>#{notes}</p>
    <p class="text-right small text-muted">#{data.taxon_credit}</p>
    """
    $("#modal-taxon-content").html(html)
    ## Bind the dismissive buttons
    # iNaturalist
    $("#modal-inat-linkout")
    .unbind()
    .click ->
      openTab("#{ssar.affiliateQueryUrl.iNaturalist}?q=#{taxon}")
    # CalPhotos
    $("#modal-calphotos-linkout")
    .unbind()
    .click ->
      openTab("#{ssar.affiliateQueryUrl.calPhotos}?rel-taxon=contains&where-taxon=#{taxon}")
    # AmphibiaWeb or Reptile Database
    # See
    # https://github.com/tigerhawkvok/SSAR-species-database/issues/35
    outboundLink = null
    buttonText = null
    if data.linnean_order.toLowerCase() in ["caudata","anura","gymnophiona"]
      # Hey, we can always HOPE to find a North American caecilian ...
      # And, if you're reading this, here's some fun for you:
      # https://www.youtube.com/watch?v=xxsUQtfQ5Ew
      # Anyway, here we want a link to AmphibiaWeb
      buttonText = "AmphibiaWeb"
      outboundLink = "#{ssar.affiliateQueryUrl.amphibiaWeb}?where-genus=#{data.genus}&where-species=#{data.species}"
    else unless isNull(data.linnean_order)
      # It's not an amphibian -- so we want a link to Reptile Database
      buttonText = "Reptile Database"
      outboundLink = "#{ssar.affiliateQueryUrl.reptileDatabase}?genus=#{data.genus}&species=#{data.species}"
    if outboundLink?
      # First, un-hide it in case it was hidden
      $("#modal-alt-linkout")
      .removeClass("hidden")
      .text(buttonText)
      .unbind()
      .click ->
        openTab(outboundLink)
    else
      # Well, wasn't expecting this! But we'll handle it anyway.
      # Hide the link
      $("#modal-alt-linkout")
      .addClass("hidden")
      .unbind()
    formatScientificNames()
    # Set the heading
    humanTaxon = taxon.charAt(0).toUpperCase()+taxon[1...]
    humanTaxon = humanTaxon.replace(/\+/g," ")
    $("#modal-taxon").attr("heading",humanTaxon)
    # Open it
    taxonArray = taxon.split("+")
    ssar.activeTaxon =
      genus: taxonArray[0]
      species: taxonArray[1]
      subspecies: taxonArray[2]
    if isNull(data.image) then data.image = undefined
    ssar.taxonImage =
      imageUri: data.image
      imageCredit: data.image_credit
      imageLicense: data.image_license
    # Insert the image
    insertModalImage()
    checkTaxonNear taxon, ->
      stopLoad()
      $("#modal-taxon")[0].open()
  .fail (result,status) ->
    stopLoadError()
  false





doFontExceptions = ->
  ###
  # Look for certain keywords to force into capitalized, or force
  # uncapitalized, overriding display CSS rules
  ###
  alwaysLowerCase = [
    "de"
    "and"
    ]
  $.each alwaysLowerCase, (i,word) ->
    # Do this to each
    false
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

clearSearch = (partialReset = false) ->
  ###
  # Clear out the search and reset it to a "fresh" state.
  ###
  $("#result-count").text("")
  calloutHtml = """
  <div class="bs-callout bs-callout-info center-block col-xs-12 col-sm-8 col-md-5">
    Search for a common or scientific name above to begin, eg, "California slender salamander" or "<span class="sciname">Batrachoseps attenuatus</span>"
  </div>
  """
  $("#result_container").html(calloutHtml)
  if partialReset is true then return false
  # Do a history breakpoint
  setHistory()
  # Reset the fields
  $(".cndb-filter").attr("value","")
  $("#collapse-advanced").collapse('hide')
  $("#search").attr("value","")
  $("#linnean-order").polymerSelected("any")
  formatScientificNames()
  false


$ ->
  devHello = """
  ****************************************************************************
  Hello developer!
  If you're looking for hints on our API information, this site is open-source
  and released under the GPL. Just click on the GitHub link on the bottom of
  the page, or check out https://github.com/SSARHERPS
  ****************************************************************************
  """
  console.log(devHello)
  # Do bindings
  # console.log("Doing onloads ...")
  animateLoad()
  # Set up popstate
  window.addEventListener "popstate", (e) ->
    uri.query = $.url().attr("fragment")
    try
      loadArgs = Base64.decode(uri.query)
    catch e
      loadArgs = ""
    console.log("Popping state to #{loadArgs}")
    performSearch(loadArgs)
    temp = loadArgs.split("&")[0]
    $("#search").attr("value",temp)
  ## Set events
  $("#do-reset-search").click ->
    clearSearch()
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
  $("#linnean-order").on "core-select", ->
    # We do want to auto-trigger this when there's a search value,
    # but not when it's empty (even though this is valid)
    if not isNull($("#search").val()) then performSearch()
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
      temp = temp.replace(/\+/g," ").trim()
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
        # console.log("Got a valid result, formatting #{result.count} results.")
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
