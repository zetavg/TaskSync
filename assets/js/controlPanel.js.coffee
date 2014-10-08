TextInput = React.createClass
  getDefaultProps: ->
    initialValue: ''
    id: ''
    className: ''
    onChange: (value) ->
      console.log value
  getInitialState: ->
    value: @props.initialValue
  handleChange: (e) ->
    @value(e.target.value)
  value: (value = @state.value) ->
    if value != @state.value
      @setState value: value
      @props.onChange(value)
    value
  render: ->
    value = @state.value
    id = @props.id
    className = @props.className
    input {type: "text", id: id, className: "form-control #{className}", value: value, onChange: @handleChange}


Settings = React.createClass
  render: ->
    div {dangerouslySetInnerHTML: __html: '<iframe src="http://ghbtns.com/github-btn.html?user=Neson&amp;repo=TaskSync&amp;type=watch&amp;count=true" allowtransparency="true" frameborder="0" scrolling="0" width="104px" height="20px"></iframe>

<h3>同步處理網址</h3>

<p>同步處理動作需要用要求 <code>' + window.location.protocol + '//' + window.location.host + '/sync?key=' + window.urlKey + '</code> 來觸發。可以由排程工具或 ping 服務來實現自動同步。</p>

<h3>日曆網址</h3>

<p>所有任務清單的 ical 訂閱網址：<code>' + window.location.protocol + '//' + window.location.host + '/ics.ics?key=' + window.urlKey + '</code></p>

<p>單一任務清單的 ical 訂閱網址在每個任務清單的右側。</p>

<p>可以在支援的行事曆軟體、服務訂閱該網址。</p>

<h3>Sync Troubleshooting</h3>

<p>大部分同步處理失敗原因為服務 API key、API secret、token 或參數設定不正確，又或是網路連線所致。</p>'}


SyncControl = React.createClass
  getDefaultProps: ->
    appData: {}
    updateParent: ->
      console.log 'updateParent called.'

  getInitialState: ->
    syncState: 'new'
    syncErrorMessage: ''
    lastSyncTime: null

  componentDidMount: ->
    @updateData()

  updateData: ->
    data = @props.appData
    if data['lastSyncAt']
      @setState lastSyncTime: new Date(data['lastSyncAt'])

  handleSync: ->
    if @state.syncState != 'syncing'
      @setState syncState: 'syncing'
      console.log 'syncing'
      $.ajax(
        url: "/sync?key=#{window.urlKey}"
        type: 'POST'
      ).done (data) =>
        if data.status != 'done'
          @setState syncState: 'error'
          @setState syncErrorMessage: (if data.errors then data.errors else []).join(', ')
          window.lastAjaxData = data
          console.log data
        else
          @setState syncState: 'done'
          window.lastAjaxData = data
          console.log data
        @props.updateParent()

  render: ->
    if !!@state.lastSyncTime && !!@state.lastSyncTime.toISOString
      d = @state.lastSyncTime
      lastSyncTime = "#{d.getFullYear()}-#{d.getMonth()+1}-#{d.getDate()} #{d.toTimeString().replace(RegExp(' .*$'), '')}"
      syncStatusText = span {},
        span {className: "hidden-xs"}, 'Last synced at: '
        lastSyncTime
        span {className: "hidden-xs"}, '.'
    else
      lastSyncTime = 'unknowen'
      syncStatusText = "Not synced yet."

    if @state.syncState == 'new'
      syncStatus = 'Sync now'
    else if @state.syncState == 'done'
      syncStatus = 'Sync done.'
    else if @state.syncState == 'syncing'
      syncStatus = 'Syncing...'
      syncStatusText = 'Now syncing...'
    else if @state.syncState == 'error'
      syncStatus = "Error(s): #{@state.syncErrorMessage}"
      syncStatusText = 'Error occurred.'
    else
      syncStatus = 'unknowen'

    div {className: "sync-control"},
      button {onClick: @handleSync, className: "btn btn-default f-left has-tooltip #{'disabled' if @state.syncState == 'syncing'} #{'btn-warning' if @state.syncState == 'error'}", 'data-toggle': "tooltip", 'data-placement': "top", title: syncStatus, 'data-original-title': syncStatus},
        span {className: "glyphicon glyphicon-refresh #{'rotate' if @state.syncState == 'syncing'}"}
      p {className: "status f-left #{@state.syncState}"}, syncStatusText
      button {className: "btn btn-default f-right has-tooltip", 'data-toggle': "tooltip", 'data-placement': "top", title: "Settings", 'data-original-title': "Settings", 'data-toggle': "modal", 'data-target': "#syncSettingsModal"},
        span {className: "glyphicon glyphicon-cog"},
      div {className: "modal fade", id: "syncSettingsModal", role: "dialog"},
        div {className: "modal-dialog"},
          div {className: "modal-content"},
            div {className: "modal-header"},
              button {type: "button", className: "close", 'data-dismiss': "modal"},
                span {'aria-hidden': "true"}, "×",
                span {className: "sr-only"}, "Close"
              h4 {className: "modal-title"}, "Settings"
            div {className: "modal-body"}, Settings()


ServiceControl = React.createClass
  getDefaultProps: ->
    appData: {}
    updateParent: ->
      console.log 'updateParent called.'

  getInitialState: ->
    serviceData: []

  updateData: ->
    data = @props.appData
    $.get '/service', (serviceData) =>
      @setState serviceData: serviceData
      $('.has-tooltip').tooltip()

  render: ->
    div {className: "service-control"},
      div {className: "panel-group", id: "service-accordion"},
        div {className: "panel panel-default"},
          div {className: "panel-heading"},
            span({className: "badge f-right"}, @state.serviceData?.length),
            h4 {className: "panel-title"},
              a {'data-toggle': "collapse", 'data-parent': "#service-accordion", href: "#services"}, "Services"
          div {id: "services", className: "panel-collapse collapse"},
            div {className: "panel-body"},
              div {},
                table {className: "table table-hover table-condensed"},
                  thead {},
                    tr {},
                      th {}, '#'
                      th {}, 'Name'
                      th {}, 'Type'
                      th {}, 'Action'
                  tbody {},
                    for service in @state.serviceData
                      Service {key: service.id, id: service.id, title: service.title, type: service.type, apiKey: service.apiKey, apiSecret: service.apiSecret, onUpdate: @props.updateParent}
              div {className: "actions"},
                button {className: "btn btn-default f-right has-tooltip", 'data-toggle': "tooltip", 'data-placement': "top", title: "Add new", 'data-original-title': "Add new", 'data-toggle': "modal", 'data-target': "#addServiceModal"},
                  span {className: "glyphicon glyphicon-plus"},
                div {className: "modal fade", id: "addServiceModal", role: "dialog"},
                  div {className: "modal-dialog"},
                    div {className: "modal-content"},
                      div {className: "modal-header"},
                        button {type: "button", className: "close", 'data-dismiss': "modal"},
                          span {'aria-hidden': "true"}, "×",
                          span {className: "sr-only"}, "Close"
                        h4 {className: "modal-title"}, "New Service to Sync From"
                      div {className: "modal-body"}, NewService({onUpdate: @props.updateParent})


Service = React.createClass
  getDefaultProps: ->
    onUpdate: ->
      console.log 'Updated'
    id: 0
    title: ''
    type: ''
    apiKey: ''
    apiSecret: ''

  delete: ->
    if confirm "確定要刪除 #{@props.title} 嗎？這會終止所有關連清單的同步！"
      $.ajax(
        url: "/service/#{@props.id}"
        type: 'DELETE'
      ).done (data) =>
        console.log data
        location.reload() if data.error
        @props.onUpdate()

  render: ->
    tr {},
      td {}, @props.id
      td {}, @props.title
      td {}, @props.type
      td {},
        div {},
          a {className: "ics btn btn-default btn-xs has-tooltip", 'data-toggle': "tooltip", 'data-placement': "top", title: "Edit", 'data-toggle': "modal", 'data-target': "#editServiceModal#{@props.id}"},
            span {className: "glyphicon glyphicon-pencil"}
          a {className: "ics btn btn-default btn-xs has-tooltip", 'data-toggle': "tooltip", 'data-placement': "top", title: "Delete", onClick: @delete},
            span {className: "glyphicon glyphicon-minus"}
          div {className: "modal fade", id: "editServiceModal#{@props.id}", role: "dialog"},
            div {className: "modal-dialog"},
              div {className: "modal-content"},
                div {className: "modal-header"},
                  button {type: "button", className: "close", 'data-dismiss': "modal"},
                    span {'aria-hidden': "true"}, "×",
                    span {className: "sr-only"}, "Close"
                  h4 {className: "modal-title"}, "Edit #{@props.title}"
                div {className: "modal-body"},
                  if @props.type == 'asana'
                    AsanaForm({onUpdate: @props.onUpdate, method: 'put', id: @props.id, name: @props.title, apiKey: @props.apiKey})
                  else if @props.type == 'trello'
                    TrelloForm({onUpdate: @props.onUpdate, method: 'put', id: @props.id, name: @props.title, apiKey: @props.apiKey, apiSecret: @props.apiSecret})


NewService = React.createClass
  getDefaultProps: ->
    onUpdate: ->
      console.log 'Updated'

  render: ->
    div {},
      ul {className: "nav nav-tabs", role: "tablist"},
        li {className: "active"},
          a {href: "#newAsana", role: "tab", 'data-toggle': "tab"}, 'Asana'
        li {className: ""},
          a {href: "#newTrello", role: "tab", 'data-toggle': "tab"}, 'Trello'
      div {className: "tab-content"},
        div {className: "tab-pane active", id: "newAsana"},
          AsanaForm({onUpdate: @props.onUpdate, method: 'post'})
        div {className: "tab-pane", id: "newTrello"},
          TrelloForm({onUpdate: @props.onUpdate, method: 'post'})


AsanaForm = React.createClass
  getDefaultProps: ->
    method: 'post'
    id: ''
    name: ''
    apiKey: ''
    onUpdate: ->
      console.log 'onUpdate called'

  getInitialState: ->
    name: @props.name
    apiKey: @props.apiKey

  updateName: (e) ->
    @setState name: e.target.value

  updateApiKey: (e) ->
    @setState apiKey: e.target.value

  sendData: ->
    if @props.method == 'post'
      $.post "/service",
        type: 'asana'
        title: @state.name
        apiKey: @state.apiKey
      , (data) =>
        console.log data
        @props.onUpdate()
        location.reload() if data.error
        @setState
          name: ''
          apiKey: ''
    else
      $.ajax(
        url: "/service/#{@props.id}"
        type: 'PUT'
        data:
          title: @state.name
          apiKey: @state.apiKey
      ).done (data) =>
        console.log data
        location.reload() if data.error
        @props.onUpdate()

  render: ->
    div {role: "form"},
      p {style: {'margin-top': "12px"}}, "Asana 帳號"
      div {className: "form-group"},
        label {}, "Name"
        input {type: "text", className: "form-control", value: @state.name, onChange: @updateName}
      div {className: "form-group"},
        label {}, "API Key"
        input {type: "text", className: "form-control", value: @state.apiKey, onChange: @updateApiKey}
      div {dangerouslySetInnerHTML: __html: '<p>Asana 的 API Key 可以在 <a target="_blank" href="http://app.asana.com/-/account_api">http://app.asana.com/-/account_api</a> 找到。</p>'}
      button {className: "btn btn-default", onClick: @sendData, 'data-dismiss': "modal"}, "Submit"

TrelloForm = React.createClass
  getDefaultProps: ->
    method: 'post'
    id: ''
    name: ''
    apiKey: ''
    apiSecret: ''
    onUpdate: ->
      console.log 'onUpdate called'

  getInitialState: ->
    name: @props.name
    apiKey: @props.apiKey
    apiSecret: @props.apiSecret

  updateName: (e) ->
    @setState name: e.target.value

  updateApiKey: (e) ->
    @setState apiKey: e.target.value

  updateApiSecret: (e) ->
    @setState apiSecret: e.target.value

  sendData: ->
    if @props.method == 'post'
      $.post "/service",
        type: 'trello'
        title: @state.name
        apiKey: @state.apiKey
        apiSecret: @state.apiSecret
      , (data) =>
        console.log data
        location.reload() if data.error
        @props.onUpdate()
        @setState
          name: ''
          apiKey: ''
          apiSecret: ''
    else
      $.ajax(
        url: "/service/#{@props.id}"
        type: 'PUT'
        data:
          title: @state.name
          apiKey: @state.apiKey
          apiSecret: @state.apiSecret
      ).done (data) =>
        console.log data
        location.reload() if data.error
        @props.onUpdate()

  render: ->
    div {role: "form"},
      p {style: {'margin-top': "12px"}}, "Trello 帳號"
      div {className: "form-group"},
        label {}, "Name"
        input {type: "text", className: "form-control", value: @state.name, onChange: @updateName}
      div {className: "form-group"},
        label {}, "APP Key"
        input {type: "text", className: "form-control", value: @state.apiKey, onChange: @updateApiKey}
      div {className: "form-group"},
        label {}, "Token"
        input {type: "text", className: "form-control", value: @state.apiSecret, onChange: @updateApiSecret}
      div {dangerouslySetInnerHTML: __html: '<p>Trello 的 APP Key 可以在 <a target="_blank" href="https://trello.com/1/appKey/generate">https://trello.com/1/appKey/generate</a> 找到，拿到 Key 後需要到以下網址再手動取得 Token： <code>https://trello.com/1/authorize?key=<span style="color: black;">your_app_key</span>&name=TaskSync&expiration=never&response_type=token&scope=read,write</code>
 (把 <code>your_app_key</code> 換成 APP Key)</p>'}
      button {className: "btn btn-default", onClick: @sendData, 'data-dismiss': "modal"}, "Submit"


ListControl = React.createClass
  getDefaultProps: ->
    appData: {}
    updateParent: ->
      console.log 'updateParent called.'

  getInitialState: ->
    listData: []

  updateData: ->
    data = @props.appData
    $.get '/list', (listData) =>
      @setState listData: listData
      $('.has-tooltip').tooltip()

  render: ->
    div {className: "list-control"},
      div {className: "list-group"},
        for list in @state.listData
          List {key: list.id, id: list.id, title: list.title, listId: list.listId, syncService: list.syncService, syncOptions: list.syncOptions, onUpdate: @props.updateParent, appData: @props.appData}


List = React.createClass
  getDefaultProps: ->
    appData: {}
    id: 0
    title: 'List'
    listId: 'list_id'
    syncService: {}
    syncOptions: ''

  getInitialState: ->
    syncService: @props.syncService.id
    syncOptions: @props.syncOptions

  updateSyncService: (e) ->
    @setState syncService: e.target.value

  updateSyncOptions: (e) ->
    @setState syncOptions: e.target.value

  sendData: ->
    $.ajax(
      url: "/list/#{@props.id}"
      type: 'PUT'
      data:
        syncService: @state.syncService
        syncOptions: @state.syncOptions
    ).done (data) =>
      console.log data
      location.reload() if data.error
      @props.onUpdate()

  render: ->
    services = array = $.map @props.appData.service, (value, index) ->
      value

    div {className: "list-group-item"},
      a {href: "#", 'data-toggle': "modal", 'data-target': "#editListModal#{@props.id}"}, @props.title
      a {href: "/ics/#{@props.listId}?key=#{window.urlKey}", target: "_blank", className: "ics btn btn-default btn-xs f-right has-tooltip", 'data-toggle': "tooltip", 'data-placement': "left", title: "iCal calender"},
        span {className: "glyphicon glyphicon-calendar"}
      if @props.syncService?.type
        div {className: "syncs-with", 'data-toggle': "modal", 'data-target': "#editListModal#{@props.id}"},
          span {className: "glyphicon glyphicon-resize-horizontal"}
          span {className: "label label-default"}, @props.syncService.title
      div {className: "modal fade", id: "editListModal#{@props.id}", role: "dialog"},
        div {className: "modal-dialog"},
          div {className: "modal-content"},
            div {className: "modal-header"},
              button {type: "button", className: "close", 'data-dismiss': "modal"},
                span {'aria-hidden': "true"}, "×",
                span {className: "sr-only"}, "Close"
              h4 {className: "modal-title"}, "Edit #{@props.title}"
            div {className: "modal-body"},
              h5 {}, "同步"
              div {role: "form"},
                div {className: "form-group"},
                  label {}, "同步服務"
                  select {className: "form-control", value: @state.syncService, onChange: @updateSyncService},
                    option {value: -1}, 'none'
                    for service in services
                      option {key: service.id, value: service.id}, service.title
                if @state.syncService > 0
                  div {className: "form-group"},
                    label {}, "同步參數"
                    input {type: "text", className: "form-control", value: @state.syncOptions, onChange: @updateSyncOptions}

                if @props.appData.service[@state.syncService]?.type == 'asana'
                  div {dangerouslySetInnerHTML: __html: '<h6>參數說明</h6><p>可以選擇整個 Workspace 中指派給我、或特定 Project 的 Task 來同步。可以用的參數格式如：</p><ul><li><code>workspace=1337&amp;assignee=me</code> 同步 Workspace ID 為 1337 裡指派給我的 Task</li><li><code>workspace=1337&amp;project=118</code> 同步 Workspace ID 為 1337 裡，Project ID 為 118 的 Task</li><li><code>workspace=1337&amp;project=118&amp;assignee=me</code> 同步 Workspace ID 為 1337 裡，Project ID 為 118 中指派給我的 Task</li></ul><p>Workspace ID 可以在 <a target="_blank" href="https://app.asana.com/api/1.0/workspaces">https://app.asana.com/api/1.0/workspaces</a> 查詢，Project ID 可以在 <a target="_blank" href="https://app.asana.com/api/1.0/projects">https://app.asana.com/api/1.0/projects</a> 找到。</p>'}
                else if @props.appData.service[@state.syncService]?.type == 'trello'
                  div {dangerouslySetInnerHTML: __html: '<p>可以選擇整個 Board，或 Board 中的某個 List 來同步。可以用的參數格式有兩種：</p><ul><li><code>board=123456789</code> 同步 ID 為 123456789 的 Board 裡的所有 Card，新增的任務會被加到 Board 中排在第一個的 List</li><li><code>list=987654321</code> 同步 ID 為 987654321 的 List 裡的 Card</li></ul><p>Board ID 可以在 <a target="_blank" href="https://trello.com/1/member/me/boards">https://trello.com/1/member/me/boards</a> 查詢，List ID 可以在 <code>https://trello.com/1/boards/<span style="color: black;">board_id</span>/lists</code> 找到。</p>'}

                button {className: "btn btn-default", onClick: @sendData, 'data-dismiss': "modal"}, "Submit"


ControlPanel = React.createClass

  getInitialState: ->
    appData: {}

  componentDidMount: ->
    @updateData()

  updateData: ->
    $.get '/data', (data) =>
      @setState appData: data
      @refs.SyncControl.updateData()
      @refs.ServiceControl.updateData()
      @refs.ListControl.updateData()
      $('.has-tooltip').tooltip()

  render: ->
    div {className: "control-panel"},
      SyncControl({ref: "SyncControl", appData: @state.appData, updateParent: @updateData})
      ServiceControl({ref: "ServiceControl", appData: @state.appData, updateParent: @updateData})
      ListControl({ref: "ListControl", appData: @state.appData, updateParent: @updateData})


window.controlPanel = React.renderComponent ControlPanel(

), document.getElementById('app-control-panel')
