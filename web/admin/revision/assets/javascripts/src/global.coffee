App = {}
App.opacity = false
App.pointerEvents = false
App.localStorageAvailable = (()->
  if window['localStorage']?
    return true
  else
    return false
)()

html = document.documentElement
attToCheck = ["pointerEvents", "opacity"]
for att in attToCheck 
  if html.style[att]?
    $(html).addClass(att)
    App[att] = true
  else
    $(html).addClass("no-#{att}") 
###
# class ModalBox {{{
###
class Modalbox
  constructor: () ->
    @modal   = $('<div class="modal"><div class="padding"></div></div>')
    @overlay = $('<span class="overlay"></span>') 
    $('body').append(@modal)
    $('body').append(@overlay)
    
    @overlay.bind('click', @close)
    
  open: ()->
    @modal.addClass('visible')
    @overlay.addClass('visible')
    
  close: () =>
    @modal.addClass('fadding')
    @overlay.addClass('fadding')
    t = setTimeout(()=>
      @modal.removeClass('visible fadding')
      @overlay.removeClass('visible fadding')
    , 150)
    
###
#}}} 
###

###
# class Confirmbox {{{
###
class Confirmbox extends Modalbox
  constructor: (template) ->
    super
    @modal.addClass('confirm-box')
    @template = template
  
  initConfirmation: (contentString, callback)->
    confirmMessage = { confirmMessage : contentString}
    confirmBoxContent = $(@template(confirmMessage))
    acceptBtn = confirmBoxContent.find('#accept')
    deniedBtn = confirmBoxContent.find('#denied')
    @modal.find('.padding').html(confirmBoxContent)
    
    acceptBtn.bind('click', ()=>
      callback()
      @close()
    )
    deniedBtn.bind('click', @close)
    
    @open();
###
#}}} 
###

###
# classCustomMap {{{
###
class CustomMap
  constructor: (id)->
    @MarkersConfig = Markers
    
    @blankTilePath = 'tiles/00empty.jpg'
    @iconsPath     = 'assets/images/icons/32x32'
    @maxZoom       = 7
    @appState      = "read"
    # HTML element
    @html             = $('html')
    @lngContainer     = $('#long')
    @latContainer     = $('#lat')
    @devModInput      = $('#dev-mod')
    @optionsBox       = $('#options-box')

    @markerList       = $('#marker-list')
    @markersOptionsMenu = $('#markers-options')
    
    # @defaultLat = 15.919073517982465
    @defaultLat = 26.765230565697536
    # @defaultLng = 18.28125
    @defaultLng = -36.32080078125
    
    @defaultCat = "generic"
    
    @areaSummaryBoxes = []
    
    @draggableMarker  = false
    @visibleMarkers   = true
    @canToggleMarkers = true
    @currentOpenedInfoWindow = false
    @gMapOptions   = 
      center: new google.maps.LatLng(@getStartLat(), @getStartLng())
      zoom: 6
      minZoom: 3
      maxZoom: @maxZoom
      streetViewControl: false
      mapTypeControl: false
      mapTypeControlOptions:
        mapTypeIds: ["custom", google.maps.MapTypeId.ROADMAP]

      panControl: false
      zoomControl: true
      zoomControlOptions:
        position: google.maps.ControlPosition.LEFT_CENTER
        zoomControlStyle: google.maps.ZoomControlStyle.SMALL
        
    @customMapType = new google.maps.ImageMapType(
      getTileUrl : (coord, zoom)=>
        normalizedCoord = coord
        if normalizedCoord && (normalizedCoord.x < Math.pow(2, zoom)) && (normalizedCoord.x > -1) && (normalizedCoord.y < Math.pow(2, zoom)) && (normalizedCoord.y > -1)
          path = 'tiles/' + zoom + '_' + normalizedCoord.x + '_' + normalizedCoord.y + '.jpg'
        else 
          return @blankTilePath
      tileSize: new google.maps.Size(256, 256)
      maxZoom: @maxZoom
      name: 'GW2 Map'
    )
    
    @map = new google.maps.Map($(id)[0], @gMapOptions)
    @map.mapTypes.set('custom', @customMapType)
    @map.setMapTypeId('custom')

    @addMenuIcons()
    
    # Events
    # google.maps.event.addListener(@map, 'click', (e)=>
      # console.log '{"lat" : "'+e.latLng.lat()+'", "lng" : "'+e.latLng.lng()+'", "title" : "", "desc" : ""},'
    # )
    
    google.maps.event.addListener(@map, 'zoom_changed', (e)=>
        zoomLevel = @map.getZoom()
        if zoomLevel == 4
          @canToggleMarkers = false
          @hideMarkersOptionsMenu()
          @setAllMarkersVisibility(false)
          @setAreasInformationVisibility(true)
          if @currentOpenedInfoWindow then @currentOpenedInfoWindow.close()
        else if zoomLevel > 4
          @canToggleMarkers = true
          @showMarkersOptionsMenu()
          @setAllMarkersVisibility(true)
          @setAreasInformationVisibility(false)
        else if zoomLevel < 4
          @canToggleMarkers = false
          @hideMarkersOptionsMenu()
          @setAllMarkersVisibility(false)
          @setAreasInformationVisibility(false)
          if @currentOpenedInfoWindow then @currentOpenedInfoWindow.close()
    )
    
    #marker
    @gMarker = {}

    @editInfoWindowTemplate = ""
    $.get('assets/javascripts/templates/customInfoWindowRead._', (e)=>
      @editInfoWindowTemplate = _.template(e)
      
      @setAllMarkers()  
      @initializeAreaSummaryBoxes()
    )
  
  addMarker:(markerInfo, markersType, markersCat)->
    createInfoWindow = (marker)=>
      templateInfo = 
        id : marker.__gm_id
        title : marker.title
        desc  : marker.desc
        type  : marker.type
        lat   : marker.position.lat()
        lng   : marker.position.lng()
        wikiLink  : marker.wikiLink
    
      editInfoWindowContent = @editInfoWindowTemplate(templateInfo)
      marker["infoWindow"] = new CustomInfoWindow(marker, editInfoWindowContent,
        onClose : () =>
          @currentOpenedInfoWindow = null
        onOpen  : (infoWindow) =>
          @currentOpenedInfoWindow = infoWindow
        onSave  : (newInfo)=>
      )
      
    iconsize = 32;
    iconmid = iconsize / 2;
    image = new google.maps.MarkerImage(@getIconURLByType(markersType, markersCat), null, null,new google.maps.Point(iconmid,iconmid), new google.maps.Size(iconsize, iconsize));
    isMarkerDraggable = if markerInfo.draggable? then markerInfo.draggable else false
    marker = new google.maps.Marker(
      position: new google.maps.LatLng(markerInfo.lat, markerInfo.lng)
      map: @map
      icon: image
      visible: if markersCat is @defaultCat then yes else no
      draggable: isMarkerDraggable
      cursor : if isMarkerDraggable then "move" else "pointer"
      title: "#{markerInfo.title}"
    )

    marker["title"] = "#{markerInfo.title}"
    marker["desc"]  = "#{markerInfo.desc}"
    marker["wikiLink"]  = "#{markerInfo.wikiLink}"
    marker["type"]  = "#{markersType}"
    marker["cat"]  = "#{markersCat}"
    

    if markerInfo.lat.toString() is @getStartLat() and markerInfo.lng.toString() is @getStartLng()
      if not marker["infoWindow"]?
        createInfoWindow(marker)
        marker["infoWindow"].open()
      else
        marker["infoWindow"].open()
        
    google.maps.event.addListener(marker, 'click', (e)=>
      # Handling infoWindow, creating them is their're not
      if marker["infoWindow"]?
        if @currentOpenedInfoWindow is marker["infoWindow"]
          @currentOpenedInfoWindow.close()
          
        else
          if @currentOpenedInfoWindow then @currentOpenedInfoWindow.close()
          marker["infoWindow"].open()
      else  
        createInfoWindow(marker)
        if @currentOpenedInfoWindow then @currentOpenedInfoWindow.close()
        marker["infoWindow"].open()
    )
    
    markerType["markers"].push(marker) for markerType in @gMarker[markersCat]["markerGroup"] when markerType.slug is markersType

  setAllMarkers:()->
    for markersCat, markersObjects of @MarkersConfig
      if not @gMarker[markersCat]?
        @gMarker[markersCat] = {}
        @gMarker[markersCat]["name"] = markersObjects.name
        @gMarker[markersCat]["markerGroup"] = []
        
      for markerTypeObject, key in markersObjects.markerGroup
        newmarkerTypeObject = {}
        newmarkerTypeObject["name"] = markerTypeObject.name
        newmarkerTypeObject["slug"] = markerTypeObject.slug
        newmarkerTypeObject["markers"] = []
        @gMarker[markersCat]["markerGroup"].push(newmarkerTypeObject)
        
        @addMarker(marker, markerTypeObject.slug, markersCat) for marker in markerTypeObject.markers
    
  getIconURLByType:(type, markersCat)->
    return Resources.Icons[markersCat][icon].url for icon of Resources.Icons[markersCat] when icon is type

  setAllMarkersVisibility:(isVisible)->
    for cat, markersObjects of @MarkersConfig
      @setMarkersVisibilityByType(isVisible, markerTypeObject.slug, cat) for markerTypeObject in markersObjects.markerGroup when not $("[data-type='#{markerTypeObject.slug}']").hasClass('off')

  setMarkersVisibilityByType:(isVisible, type, cat)->
    for markerTypeObject in @gMarker[cat]["markerGroup"] when markerTypeObject.slug is type
      marker.setVisible(isVisible) for marker in markerTypeObject.markers

  
  setMarkersVisibilityByCat:(isVisible, cat)->
    for markerTypeObject in @gMarker[cat]["markerGroup"]
      marker.setVisible(isVisible) for marker in markerTypeObject.markers
                    
  getStartLat:()->
    params = extractUrlParams()
    if params['lat']?
        params['lat']
    else
        @defaultLat
    
  getStartLng:()->
      params = extractUrlParams()
      if params['lng']?
          params['lng']
      else
          @defaultLng
  
  setDraggableMarker:(val)->
    unDrag = (marker)->
      marker.setDraggable(false)
      marker.setCursor('pointer')
      
    for type, markersObjects of @gMarker
      for markerTypeObject, key in markersObjects.markerGroup
        unDrag(marker) for marker in markerTypeObject.markers
        
  getMarkerByCoordinates:(lat, lng)->
    for markersCat, markersObjects of @MarkersConfig
      for markerTypeObject, key in markersObjects.markerGroup
        return marker for marker in markerTypeObject.markers when marker.lat is lat and marker.lng is lng
    return false  
      
  turnOfMenuIconsFromCat:(markerCat)->
    menu = $(".menu-marker[data-markerCat='#{markerCat}']")
    menu.find('.group-toggling').addClass('off')
    menu.find('.trigger').addClass('off')
  
  addMenuIcons:()->
    markersOptions = $.get('assets/javascripts/templates/markersOptions._', (e)=>
      template = _.template(e);
      html = $(template(Resources))
      
      # Binding click on marker icon in markers option list
      html.find(".trigger").bind 'click', (e) =>
        item           = $(e.currentTarget)
        myGroupTrigger = item.closest(".menu-marker").find('.group-toggling')
        markerType     = item.attr('data-type')
        markerCat      = item.attr('data-cat')
        
        if @canToggleMarkers
          if item.hasClass('off')
            @setMarkersVisibilityByType(true, markerType, markerCat)
            item.removeClass('off')
            myGroupTrigger.removeClass('off')
          else
            @setMarkersVisibilityByType(false, markerType, markerCat)
            item.addClass('off')
        
      
      html.find('.group-toggling').bind 'click', (e)=>
        this_ = $(e.currentTarget)
        parent = this_.closest('.menu-marker')
        markerCat = parent.attr('data-markerCat')
        if this_.hasClass('off')
          this_.removeClass('off')
          @setMarkersVisibilityByCat(on, markerCat)
          parent.find('.trigger').removeClass('off')
        else
          this_.addClass('off')
          @setMarkersVisibilityByCat(off, markerCat)
          parent.find('.trigger').addClass('off')
            
      @markersOptionsMenu.find('.padding').prepend(html)
      @turnOfMenuIconsFromCat(markerCat) for markerCat of @MarkersConfig when markerCat isnt @defaultCat
    )
      
  initializeAreaSummaryBoxes:()->
    for area of Areas
        @areaSummaryBoxes[area] = new AreaSummary(@map, Areas[area])
        
  setAreasInformationVisibility:(isVisible)->
    for box in @areaSummaryBoxes
      box.setVisible(isVisible)
  toggleMarkersOptionsMenu: () ->
    @markersOptionsMenu.toggleClass('active')
  hideMarkersOptionsMenu: () ->
    @markersOptionsMenu.addClass('off')
  showMarkersOptionsMenu: () ->
    @markersOptionsMenu.removeClass('off')

###
# }}}
###
 
###
# class AreaSummary {{{
###
class AreaSummary
    constructor:(map, area)->
        swBound = new google.maps.LatLng(area.swLat, area.swLng)
        neBound = new google.maps.LatLng(area.neLat, area.neLng)
        @bounds_ = new google.maps.LatLngBounds(swBound, neBound)
        @area_ = area
        @div_ = null
        @height_ = 80
        @width_ = 150
        @template = ""
        $.get('assets/javascripts/templates/areasSummary._', (e)=>
          @template = _.template(e)
          @setMap(map)
        )
    
    AreaSummary:: = new google.maps.OverlayView();
    
    onAdd:()->
        content = @template(@area_)
        @div_ = $(content)[0]
        panes = @getPanes()
        panes.overlayImage.appendChild(@div_)
        @setVisible(false)
        
    draw:()->
      overlayProjection = @getProjection()
      sw = overlayProjection.fromLatLngToDivPixel(this.bounds_.getSouthWest());
      ne = overlayProjection.fromLatLngToDivPixel(this.bounds_.getNorthEast());

      div = this.div_;
      div.style.left = sw.x + ((ne.x - sw.x) - @width_) / 2 + 'px';
      div.style.top = ne.y + ((sw.y - ne.y) - @height_) / 2 + 'px';
    
    setVisible:(isVisible)->
      if @div_
          if isVisible is true
              @div_.style.visibility = "visible"
          else
              @div_.style.visibility = "hidden"
###
# }}}
###                

###
# class AreaSummary {{{
###
class CustomInfoWindow
  constructor: (marker, content, opts) ->
    @content = content
    @marker  = marker
    @template = opts.template
    @map     = marker.map
    wrap = """
    <div class="customInfoWindow">
      <a href="javascript:" title="Close" class="close button"></a>
        <div class="padding"></div>
    </div>
    """
    @wrap = $(wrap)
    @closeBtn = @wrap.find('.close')
    @setMap(@map)
    @isVisible = false
    @onClose   = opts.onClose
    @onOpen    = opts.onOpen
    @onSave    = opts.onSave
    @closeBtn.bind('click', @close)

  CustomInfoWindow:: = new google.maps.OverlayView()
  
  
  onAdd:()->
      @wrap.find('.padding').append(@content)
      @wrap.css(
        display: "block"
        position: "absolute"
      )
      panes = @getPanes()
      panes.overlayMouseTarget.appendChild(@wrap[0])
      @iWidth = @wrap.outerWidth()
      @iHeight = @wrap.outerHeight()
      # @open()

    
  onRemove :() ->
    # console.log @wrap.parent()
    @wrap[0].parentNode.removeChild(@wrap[0])
    @wrap = null
    
  draw: () ->
    cancelHandler = (e)=>
        e.cancelBubble = true
        if e.stopPropagation
          e.stopPropagation()
    
    overlayProjection = @getProjection()
    pos = overlayProjection.fromLatLngToDivPixel(@marker.position)
    @wrap.css(
      left: pos.x + 30
      top: pos.y - 80
    )
    
    events = ['mousedown', 'touchstart', 'touchend', 'touchmove', 'contextmenu', 'click', 'dblclick', 'mousewheel', 'DOMMouseScroll']
    @listeners = []
    for event in events
      @listeners.push(google.maps.event.addDomListener(@wrap[0], event, cancelHandler);)
    
  close:()=>
    if @wrap
      @onClose(this)
      @isVisible = false
      @wrap.css(
        display : "none"
      )
  open:()=>
    if @wrap
      @panMap()
      @onOpen(this)
      @isVisible = true
      @wrap.css(
        display : "block"
      )
  
  updatePos: ()->
    overlayProjection = @getProjection()
    pos = overlayProjection.fromLatLngToDivPixel(@marker.position)

    shareInput = @wrap.find('[name="share-link"]') 
    val = shareInput.val()
    newVal = val.split("?")[0] + "?lat=" + @marker.position.lat() + "&lng=" + @marker.position.lng()
    shareInput.val(newVal)

    @wrap.css(
      left: pos.x + 30
      top: pos.y - 80
    )

  handleSave: (e) =>
    this_ = $(e.currentTarget)
    form = @wrap.find('.edit-form')
    newTitle = @wrap.find('[name="marker-title"]').val()
    newDesc = @wrap.find('[name="marker-description"]').val()
    newWikiLink = @wrap.find('[name="marker-wiki"]').val()
    form.removeClass('active')
    newInfo = 
      id    : @marker.__gm_id
      title : newTitle
      desc  : newDesc
      wikiLink : newWikiLink
      type : @marker.type
      cat  : @marker.cat
      lat  : @marker.position.lat()
      lng  : @marker.position.lng()
    @wrap.find('.padding').html(@template(newInfo))

    @wrap.find('.edit').removeClass('active')
    @onSave(newInfo)
  
  panMap: () -> 
    @map.panTo(new google.maps.LatLng(@marker.position.lat(), @marker.position.lng()));

###
# }}}
###

extractUrlParams = ()->
    parameters = location.search.substring(1).split('&')
    f = []
    for element in parameters
        x = element.split('=')
        f[x[0]]=x[1]
    f
    
$ ()->
  myCustomMap = new CustomMap('#map')
  markersOptionsMenuToggle = $('#options-toggle strong')
  markersOptionsMenuToggle.click( () ->
    myCustomMap.toggleMarkersOptionsMenu()
  )