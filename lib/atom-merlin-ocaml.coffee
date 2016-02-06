AtomMerlinOcamlView = require './atom-merlin-ocaml-view'
{CompositeDisposable} = require 'atom'

module.exports = AtomMerlinOcaml =
  atomMerlinOcamlView: null
  modalPanel: null
  subscriptions: null
  editorsDisposable: null
  merlin: null

  activate: (state) ->
    @atomMerlinOcamlView = new AtomMerlinOcamlView(state.atomMerlinOcamlViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @atomMerlinOcamlView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'merlin:check': => @checkMerlin()

    # Start a Merlin background process.
    @startMerlinProcess()

    # When files are saved we need to be notified so we can query Merlin for warnings and such.
    @editorsDisposable = atom.workspace.observeTextEditors (editor) => editor.onDidSave( (event) => @fileSaved(editor, event) )

  deactivate: ->
    @editorsDisposable.dispose()
    @modalPanel.destroy()
    @subscriptions.dispose()
    @atomMerlinOcamlView.destroy()
    @merlin.kill()

  serialize: ->
    atomMerlinOcamlViewState: @atomMerlinOcamlView.serialize()

  checkMerlin: ->
    # TODO remove or implement this manual run of merlin.
    console.log 'Running...'
    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()

  startMerlinProcess: ->
    spawn = require('child_process').spawn
    @merlin = spawn 'ocamlmerlin', []
    console.log "Merlin process started, pid = #{@merlin.pid}"
    @merlin.on 'exit', (code) -> console.log "Merlin exited with code #{code}"

  queryMerlin: (query) ->
    stdin = @merlin.stdin
    stdout = @merlin.stdout
    new Promise (resolve, reject) =>
      {createInterface} = require('readline')
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
      stdin.write jsonQuery

  fileSaved: (editor, event) ->
    path = require 'path'
    if path.extname(event.path) not in ['.ml', '.mli'] then return

    # Destroy any markers we've added previously (but don't mess with other markers)
    # TODO maybe find a prettier solution here... seems like it should be possible
    # to have our own marker layer but the API is experimental and not really working.
    for marker in editor.findMarkers({merlin: true})
      marker.destroy()

    # TODO actually learn coffeescript and find a less ugly way to chain promises...
    # NOTE chaining/serializing merlin command/response handling for now...
    @queryMerlin({"context": ["auto", event.path], "query": ["tell", "start", "at", {"line":1, "col":0}]}).then =>
      @queryMerlin({"context": ["auto", event.path], "query": ["tell", "file-eof", event.path]}).then =>
        errorQuery = {"context": ["auto", event.path], "query": ["errors"]}
        errorPromise = @queryMerlin errorQuery
        errorPromise.then (payload) =>
          for err in payload
            # rows/columns in Atom are zero-indexed.
            # rows in merlin are 1-indexed, columns are 0-indexed.
            line1 = err.start.line - 1
            col1 = err.start.col
            line2 = err.end.line - 1
            col2 = err.end.col
            console.error "start:#{line1},#{col1}, end:#{line2},#{col2}"
            element = document.createElement('div')
            element.textContent = err.message
            marker = editor.markBufferRange([[line1,col1],[line2,col2]], {invalidate: 'inside', merlin: true})
            editor.decorateMarker(marker, {type: 'block', position: 'after', item: element})
            editor.decorateMarker(marker, {type: 'highlight', class: 'merlin-error'})
            editor.decorateMarker(marker, {type: 'line-number', class: 'merlin-error'})
