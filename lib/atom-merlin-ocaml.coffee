AtomMerlinOcamlView = require './atom-merlin-ocaml-view'
{CompositeDisposable} = require 'atom'

module.exports = AtomMerlinOcaml =
  atomMerlinOcamlView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @atomMerlinOcamlView = new AtomMerlinOcamlView(state.atomMerlinOcamlViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @atomMerlinOcamlView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-merlin-ocaml:toggle': => @toggle()

    atom.workspace.observeTextEditors (editor) => editor.onDidSave(@fileSaved)

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @atomMerlinOcamlView.destroy()

  serialize: ->
    atomMerlinOcamlViewState: @atomMerlinOcamlView.serialize()

  toggle: ->
    console.log 'AtomMerlinOcaml was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()

  fileSaved: (event) ->
    console.log 'file saved: ' + event.path
