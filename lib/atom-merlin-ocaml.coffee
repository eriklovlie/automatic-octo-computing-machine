spawn = require('child_process').spawn
{createInterface} = require('readline')
{CompositeDisposable} = require 'atom'

module.exports = AtomMerlinOcaml =

  config:
    merlinpath:
      type: 'string'
      default: 'ocamlmerlin'

  merlin: null
  configSubscription: null
  subscriptions: null
  editors: null
  typeAtCached: null
  typeAtIndex: 0
  showTypeCached: null

  activate: (state) ->
    @configSubscription =
      atom.config.observe 'linter-ocaml.merlinpath', (newValue, previous) =>
        @restartMerlinProcess(newValue)
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'linter-ocaml:locate': => @locate()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'linter-ocaml:locate-return': => @returnFromLocate()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'linter-ocaml:type-of': => @getSymbolType()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'linter-ocaml:type-of-narrow': => @getSymbolTypeNarrow()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'linter-ocaml:type-of-widen': => @getSymbolTypeWiden()
    # Listen for changes to ocaml files so we can sync changes with Merlin.
    @editors = {}
    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      if @isOcamlEditor(editor)
        # Use an object as a set over ocaml files
        @editors[editor.getPath()] = editor

  isOcamlEditor: (editor) ->
    # TODO there must be a better way to get only editors/buffers
    # for which this package is active. getGrammar doesn't seem to be it.
    # For now just check the file extension.
    # TODO yes there is, see here (although nuclide also checks the ext):
    # https://github.com/facebooknuclideapm/nuclide-ocaml/blob/master/lib/HyperclickProvider.js
    if atom.workspace.isTextEditor(editor)
      p = editor.getPath()
      ext = p.split('.').pop()
      ext in ['ml', 'mli']
    else
      false

  deactivate: ->
    @merlin.kill() if @merlin?
    @configSubscription.dispose()
    @subscriptions.dispose()
    @editors = {}

  restartMerlinProcess: (path) ->
    @merlin.kill() if @merlin?
    @merlin = spawn path, []
    @merlin.on 'exit', (code) -> console.log "Merlin exited with code #{code}"
    console.log "Merlin process (#{path}) started, pid = #{@merlin.pid}"

  queryMerlin: (query) ->
    stdin = @merlin.stdin
    stdout = @merlin.stdout
    new Promise (resolve, reject) =>
      reader = createInterface({
        input: stdout,
        terminal: false,
      })

      reader.on 'line', (line) =>
        reader.close()
        [kind, payload] = JSON.parse(line)
        if kind == "return"
          resolve payload
        else
          console.error "Merlin returned error response"
          reject(Error(line))

      jsonQuery = JSON.stringify(query)
      console.log jsonQuery.substring(0,300)
      stdin.write jsonQuery

  mkQuery: (path, q) ->
    {"context": ["auto", path], "query": q}

  txPos: (line, col) ->
    # Merlin wants the first line to be 1.
    {"line": line+1, "col": col}

  rxPos: (p) ->
    # Create an atom pos from what we received from merlin
    [p.line-1, p.col]

  syncFile: (path) ->
    @queryMerlin(@mkQuery(path, ["tell", "start", "at", @txPos(0,0)])).then =>
      @queryMerlin(@mkQuery(path, ["tell", "file-eof", path]))

  syncBuffer: (path, editor) ->
    text = editor.getText()
    @queryMerlin(@mkQuery(path, ["tell", "start", "at", @txPos(0,0)])).then =>
      @queryMerlin(@mkQuery(path, ["tell", "source-eof", text]))

  syncAll: ->
    # TODO this should avoid syncing stuff that hasn't changed...
    # TODO in particular it shouldn't send a ton of json with the buffer contents...
    last = null
    for path, editor of @editors
      current = if editor.isModified()
        @syncBuffer(path, editor)
      else
        @syncFile(path)
      if last?
        last.then(current)
      last = current
    last

  locate: ->
    editor = atom.workspace.getActiveTextEditor()
    if @isOcamlEditor(editor)
      path = editor.getPath()
      pos = editor.getCursorBufferPosition()
      @syncAll().then =>
        query = @mkQuery(path,
          ["locate",null,"ml","at",@txPos(pos.row, pos.column)])
        @queryMerlin(query).then (resp) =>
          jsonResp = JSON.stringify(resp)
          console.log "Resp: #{jsonResp}"

  returnFromLocate: ->
    # Go back to the last place before using locate.
    console.log "TODO return from locate"

  getTypeAt: (path, pos) ->
    @syncAll().then =>
      query = @mkQuery(path,
        ["type","enclosing","at",@txPos(pos.row, pos.column)])
      @queryMerlin(query).then (resp) =>
        jsonResp = JSON.stringify(resp)
        console.log "Resp: #{jsonResp}"
        resp

  showTypeAt: (editor, pos) ->
    if @showTypeCached?
      @showTypeCached.marker.destroy()
      @showTypeCached.notification.dismiss()
    path = editor.getPath()
    @getTypeAt(path, pos).then (resp) =>
      @typeAtCached = resp
      if resp.length > 0
        @showTypeCached = @addTypeAtDecoration(editor, resp[0])

  getSymbolType: ->
    editor = atom.workspace.getActiveTextEditor()
    if @isOcamlEditor(editor)
      # Ask merlin for type and show the narrowest context
      pos = editor.getCursorBufferPosition()
      @showTypeAt(editor, pos)

  getSymbolTypeWiden: ->
    editor = atom.workspace.getActiveTextEditor()
    if @isOcamlEditor(editor) and @typeAtCached?
      if @showTypeCached?
        @showTypeCached.marker.destroy()
        @showTypeCached.notification.dismiss()
      if @typeAtIndex < @typeAtCached.length - 1
        @typeAtIndex += 1
        typeat = @typeAtCached[@typeAtIndex]
        @showTypeCached = @addTypeAtDecoration(editor, typeat)

  getSymbolTypeNarrow: ->
    editor = atom.workspace.getActiveTextEditor()
    if @isOcamlEditor(editor) and @typeAtCached?
      if @showTypeCached?
        @showTypeCached.marker.destroy()
        @showTypeCached.notification.dismiss()
      if @typeAtIndex > 0
        @typeAtIndex -= 1
        typeat = @typeAtCached[@typeAtIndex]
        @showTypeCached = @addTypeAtDecoration(editor, typeat)

  addTypeAtDecoration: (editor, typeat) ->
    range = [
      @rxPos(typeat.start),
      @rxPos(typeat.end)
    ]
    marker = editor.markBufferRange(range)
    editor.decorateMarker(marker, type: 'highlight', class: "highlight-blue")
    # NOTE atom notification expects markdown, which we need to escape
    txt = "```#{typeat.type}```"
    n = atom.notifications.addInfo(txt, {dismissable: true})
    n.onDidDismiss =>
      marker.destroy()
    { marker: marker, notification: n }

  provideHyperclick: ->
    # OSX: holding down cmd calls getSuggestionForWord()
    getSuggestionForWord = (editor, text, range) =>
      if @isOcamlEditor(editor)
        range: range,
        callback: =>
          @showTypeAt(editor, range.start)
      else
        null
    providerName: "linter-ocaml"
    getSuggestionForWord: getSuggestionForWord

  provideLinter: ->
    name: 'OCaml Linter'
    grammarScopes: ['source.ocaml']
    scope: 'file'
    lintOnFly: false
    lint: (editor) =>
      path = editor.getPath()
      new Promise (resolve, reject) =>
        @syncAll().then =>
          @queryMerlin(@mkQuery(path, ["errors"])).then (payload) =>
            errors = []
            for e in payload
              err =
                type: if e.type == 'Warning' then 'Warning' else 'Error'
                text: e.message
                range: [
                  @rxPos(e.start),
                  @rxPos(e.end)
                ]
                filePath: path
              errors.push err
            resolve(errors)
